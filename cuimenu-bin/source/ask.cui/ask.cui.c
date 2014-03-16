#include <cui.h>
#include <cui-util.h>

void quit(void)
{
    WindowEnd();
} 



int
main(int argc, char* argv[])
{
    WindowStart(TRUE, TRUE);
    atexit(quit);

    if ( argv[1] == NULL ) {
        MessageBox(WindowGetDesktop(), _T("Missing program parameter!\n"
                                         "Start with: ask.cui 'My question?'\n"
                                         "or use: --err 'Text'  --inf 'Text'"),
                                          _T("Error"), MB_ERROR);
       return 1;
    }

    if ( strncmp(argv[1],"--err",5) == 0 )  {
       if ( argv[2] == NULL ) {
           MessageBox(WindowGetDesktop(), _T("Missing program parameter!\nStart with: ask.cui --err 'My error!'") , _T("Error"), MB_ERROR);
           return 1;
       } else {
           MessageBox(WindowGetDesktop(), MbToTCharDup( argv[2] ) , _T("Error"), MB_ERROR);
           return 0;
       }
    }

    if ( strncmp(argv[1],"--inf",5) == 0 )  {
       if ( argv[2] == NULL ) {
           MessageBox(WindowGetDesktop(), _T("Missing program parameter!\nStart with: ask.cui --inf 'My information!'") , _T("Error"), MB_ERROR);
           return 1;
       } else {
           MessageBox(WindowGetDesktop(), MbToTCharDup( argv[2] ) , _T("Information"), MB_OK);
           return 0;
       }
    }

    if ( strncmp(argv[1],"--err",5) == 0 )  {
       if ( argv[2] == NULL ) {
           MessageBox(WindowGetDesktop(), _T("Missing program parameter!\nStart with: ask.cui --err 'My error!'") , _T("Error"), MB_ERROR);
           return 1;
       } else {
           MessageBox(WindowGetDesktop(), MbToTCharDup( argv[2] ) , _T("Error"), MB_ERROR);
           return 0;
       }
    }

    if ( MessageBox(WindowGetDesktop(), MbToTCharDup( argv[1] ) , _T("Attention"), MB_YESNO) == IDYES ) {
       return 0;
    } else {
       return 1;
    }

}

