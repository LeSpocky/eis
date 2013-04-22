#define CFG_NONE        0x0
#define CFG_ID          0x1
#define CFG_DEP_ID      0x2
#define CFG_OPT_ID      0x4
#define CFG_REALLY_OPT_ID  0x8
#define CFG_STRING      0x10
#define CFG_ML_STRING   0x20
#define CFG_REGEXP      0x40
#define CFG_COMMENT     0x80
#define CFG_WCOMMENT    0x100
#define CFG_EQUAL       0x200
#define CFG_COLON       0x400
#define CFG_HYPHEN      0x800
#define CFG_NL          0x1000
#define CFG_UNKNOWN     0x2000
#define CFG_NEG_ID      0x4000

#define CFG_EOF -2
#define CFG_ERROR -3

struct cfglval_t {
    char * text;
    int column;
    int dq;
};

struct token_t {
    int allowed_tokens;
    int token;
    int dq;
    int line;
    char * text;
};

#define TOKEN(x) (struct token_t){x, 0, 0, 0, ""}

extern struct cfglval_t cfglval;
extern int cfgline;
extern int cfgcolumn;
extern int cfg_flex_debug;

void cfg_fopen (char * file);
void cfg_fclose (void);
int get_config_tokens (struct token_t * t, int ignore_nl);
