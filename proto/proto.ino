// Arduino prototype for Boom game
// Hardware requirements:
//	Arduino Uno
//	SeedStudio TFT touch screen v1.0
//

#include <stdint.h>
#include <TouchScreen.h>
#include <TFT.h>

// Pins for touch screen
#define YP A2
#define XM A1
#define YM 14
#define XP 17

#define RGB(r,g,b) (((r/4) << 10) | ((g/8) << 5) | (b/8))

#ifdef CRAZY_COLORS
#define SKY RGB(174, 196, 232)
#define EARTH GREEN
#define BUTTON_COLOR RGB(188, 124, 180)
#define CURSOR_COLOR BLACK
#define BALL_COLOR RED
#define PLAYER_1_COLOR RGB(15, 79, 21)
#define PLAYER_2_COLOR RGB(104, 65, 7)
#else
#define SKY BLACK
#define EARTH GREEN
#define BUTTON_COLOR WHITE
#define CURSOR_COLOR WHITE
#define BALL_COLOR WHITE
#define PLAYER_1_COLOR BLUE
#define PLAYER_2_COLOR RED
#endif

// Limits for touch screen
#define TS_MINX 140
#define TS_MAXX 900
#define TS_MINY 120
#define TS_MAXY 940

#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT 240

#define AVG_WINDOW 16

#define TANK_WIDTH  30
#define TANK_HEIGHT 7
#define TURR_WIDTH  10
#define TURR_HEIGHT 7

#define BUTTON_WIDTH 32
#define BUTTON_HEIGHT (TANK_HEIGHT + TURR_HEIGHT + 4)

#define CURSOR_WIDTH  10
#define CURSOR_HEIGHT 10

#define TALLY_HEIGHT 16
#define TALLY_WIDTH 6

#define SCALE 64L
#define SCALED 64.0
#define FRATE 16L
#define FRATED 16.0

// Data structures
struct vector
{
  int x,y;
};

struct rect
{
    int x,y;
    int width, height;
};

struct player
{
    int color;
    unsigned char score;
    vector pos;         // Tank position
    vector cur;         // Aiming cursor position
    rect button;
    rect turr;
    rect tank;
    rect tally[2];
};

// Static data
const struct rect screen = {0, 0, SCREEN_WIDTH, SCREEN_HEIGHT};
const vector center_screen = {SCREEN_WIDTH/2, SCREEN_HEIGHT/2};
const struct rect tank_model = {0,0,TANK_WIDTH,TANK_HEIGHT};
const struct rect turr_model = {(TANK_WIDTH-TURR_WIDTH)/2,TANK_HEIGHT,TURR_WIDTH,TURR_HEIGHT};
const struct rect button_model = {-1, -2, BUTTON_WIDTH, BUTTON_HEIGHT};
const struct rect tally1_model = {64, SCREEN_HEIGHT-TALLY_HEIGHT, TALLY_WIDTH, TALLY_HEIGHT};
const struct rect tally2_model = {64 + TALLY_WIDTH*2, SCREEN_HEIGHT-TALLY_HEIGHT, TALLY_WIDTH, TALLY_HEIGHT};
const vector firing_offset = {TANK_WIDTH/2, TURR_HEIGHT + TANK_HEIGHT};

// Statically initialized data
unsigned char rseed = 0x1;
vector acc = {0,-2};

// Dynamically intiailized data
TouchScreen ts = TouchScreen(XP, YP, XM, YM, 300); 
vector pos, vel, scn;
player players[2];
player *me, *him;

int terrain[SCREEN_WIDTH+AVG_WINDOW];

void setup()
{
  Serial.begin(9600);
  Tft.init();  //init TFT library
  pinMode(0,OUTPUT);
}

void loop()
{
  play_game();
}

void play_game()
{
  me = &players[0];
  him = &players[1];

  players[0].score = 0;
  players[1].score = 0;
  generate_terrain();
  
  while (me->score < 3 && him->score < 3)
  {
      ready();
      aim();
      fire();

      struct player* t = me;
      me = him;
      him = t;
  }

  delay(2000);
}

void ready()
{
  scn = me->pos;
  add_vec(&scn, &firing_offset);
  scale_vec(&pos, &scn);
  draw_terrain();
  draw_rect(&me->button, BUTTON_COLOR);
  draw_player(me);
  draw_player(him);
  draw_cursor(&me->cur, CURSOR_COLOR);  
}

void aim()
{   
  for (;;)
  {
    // Create entropy      
    my_rand();
    
    TSPoint p = ts.getPoint();
    if (p.z > ts.pressureThreshhold)
    {        
        vector c;
        
        // Erase cursor
        draw_cursor(&me->cur, SKY);

        // Read new cursor position
        c.y = mapx(p.x);
        c.x = mapy(p.y);
          
        if (hit_rect(&me->button, &c))
        {
          // Compute velocity and exit
          vel = me->cur;
          printvec("vel=", &vel);
          printvec("me->pos=", &me->pos);
          subtract_vec(&vel, &me->pos);
          printvec("vel=", &vel);
          Serial.println();

          // Hide button
          draw_rect(&me->button, SKY);
          draw_tank(me, me->color);
          return;
        }
        else
        { 
          me->cur = c;
          // Redraw cursor in new position
          draw_cursor(&me->cur, CURSOR_COLOR);
          printvec(" c=", &me->cur);
          Serial.println();
        }      
    }
  }  
}

void fire()
{
  double t = 0;

  for (;;)
  {
    t += 1.0/FRATED;
    add_vec(&vel, &acc);
    add_vec(&pos, &vel);
    descale_vec(&scn, &pos);
    Serial.print("t=");
    Serial.print(t);
    printvec(" acc=",&acc);
    printvec(" vel=",&vel);
    printvec(" pos=",&pos);
    printvec(" scn=",&scn);
    Serial.println();

    if (!hit_rect(&screen, &scn))
    {
        // Out of bounds
        break;
    }
    if (hit_rect(&me->tank, &scn))
    {
        him->score++;
        flash_tank(me);
        return;
    }
    else if (hit_rect(&him->tank, &scn))
    {
        me->score++;
        flash_tank(him);
        return;
    }
    else if (scn.y <= terrain[scn.x])
    {
        // Hit terrain
        break;
    }
    else
    {
        // Draw ball
        Tft.setPixel(scn.y, scn.x, BALL_COLOR);
        delay(1000/FRATE);
    }      
  }

  // missed
  delay(2000);  
}

// Graphics routines
void draw_tank(const struct player* p, int color)
{
  draw_rect(&p->turr, color);
  draw_rect(&p->tank, color);
}

void draw_cursor(const vector* v, int color)
{
  Tft.drawLine(v->y-CURSOR_HEIGHT/2, v->x, v->y+CURSOR_HEIGHT/2, v->x, color);
  Tft.drawLine(v->y ,v->x-CURSOR_WIDTH/2, v->y, v->x+CURSOR_WIDTH/2, color);  
}

void draw_rect(const rect* r, unsigned color)
{
  Tft.fillRectangle(r->y, r->x, r->height, r->width, color);
}

void draw_player(const player* p)
{
    draw_tank(p, p->color);  
    for (int i=0;i<p->score;i++)
    {
      draw_rect(&p->tally[i], p->color);
    }
}

void flash_tank(const player* p)
{
    for (int i=0;i<4;i++)
    {
        draw_tank(p, SKY);
        delay(1000/8);
        draw_tank(p, p->color);
        delay(1000/8);
    }
    
    generate_terrain();
}

void position_player(player* p, int x, int color, int tally_x)
{
    p->color = color;
    p->pos.x = x;
    p->pos.y = terrain[x]+2;
    p->cur = center_screen;
    p->tank = tank_model;
    p->turr = turr_model;
    p->button = button_model;
    offset_rect(&p->tank, &p->pos);
    offset_rect(&p->turr, &p->pos);
    offset_rect(&p->button, &p->pos);
    p->tally[0] = tally1_model;
    p->tally[0].x += tally_x;
    p->tally[1] = tally2_model;
    p->tally[1].x += tally_x;

    Serial.print("tank=");
    print_rect(&p->tank);
    Serial.print("turr=");
    print_rect(&p->turr);
    Serial.print("button=");
    print_rect(&p->button);
    Serial.print("tally1=");
    print_rect(&p->tally[0]);
    Serial.print(" color=");
    Serial.print(p->color, HEX);
    Serial.println();
}

// Smooths the terrain
void average_terrain()
{
    int* y = terrain;
    int* z = terrain+AVG_WINDOW;
    int total = *y*AVG_WINDOW;
    while (y < terrain+SCREEN_WIDTH)
    {
      int adj = *z - *y;
      *y = total/AVG_WINDOW;
      total += adj;
      y++;
      z++;
    }
}

void generate_terrain()
{
    Serial.print("Terrain seed=");
    Serial.print(rseed);
    Serial.println();
    
    int r = 0;
    int n = 0;
    while (n < SCREEN_WIDTH+AVG_WINDOW)
    {
        if (!(n & 63))
        {
            r = my_rand() % 128;
        }
        terrain[n] = r;
        n++;
    }

    average_terrain();
    average_terrain();

    position_player(players, (my_rand() & 64), PLAYER_1_COLOR, 0);
    position_player(players+1, (my_rand() & 64)+192, PLAYER_2_COLOR, SCREEN_WIDTH/2);
}

void draw_terrain()
{
    Tft.setXY(0,0);
    for (int x=0;x<SCREEN_WIDTH;x++)
    {
        int y = terrain[x];
        Tft.drawHorizontalLine(0,x,y, EARTH);
        Tft.drawHorizontalLine(y,x,SCREEN_HEIGHT-y, SKY);
    }
}

int mapx(int x)
{
    x -= TS_MINX;
    return SCREEN_HEIGHT - (((x << 2) + (x << 1)) / 19);
}

int mapy(int y)
{
  y -= TS_MINY;
  return SCREEN_WIDTH - ((y << 4) / 41);
}

// Vector methods
void printvec(const char* label, vector* v)
{
  Serial.print(label);
  Serial.print(v->x);
  Serial.print(",");
  Serial.print(v->y);
}

void add_vec(vector* dest, const vector* src)
{
    dest->x += src->x;
    dest->y += src->y;
}

void subtract_vec(vector* dest, const vector* src)
{
    dest->x -= src->x;
    dest->y -= src->y;
}

void scale_vec(vector* dest, const vector* src)
{
    dest->x = src->x * SCALE;
    dest->y = src->y * SCALE;
}

void descale_vec(vector* dest, const vector* src)
{
    dest->x = src->x / SCALE;
    dest->y = src->y / SCALE;
}

// Rectangle methods
void print_rect(struct rect* r)
{
    Serial.print("[");
    Serial.print(r->x);
    Serial.print(",");
    Serial.print(r->y);
    Serial.print(",");
    Serial.print(r->width);
    Serial.print(",");
    Serial.print(r->height);
    Serial.print("]");
}

void offset_rect(struct rect* r, const vector* v)
{
  r->x += v->x;
  r->y += v->y;
}

int hit_rect(struct rect* r, const vector* v)
{
    vector a = *v;
    subtract_vec(&a, (vector*)r);
    return a.x >= 0 && a.y>=0 && a.x < r->width && a.y < r->height;
}

// Random number generator
unsigned char my_rand()
{
    unsigned char eor = 0;
    if (rseed & 1)
      eor = 0xb4;
    rseed = rseed >> 1;
    rseed ^= eor;
    return rseed;      
}

