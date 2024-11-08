#include <stdlib.h>
#include <string.h>

    #include <tcl.h> 
    #include <tk.h> 

int InitProc( Tcl_Interp *interp ) {

    int iRet;

    // Initialize tk first 
    iRet = Tk_Init( interp ); 
    if( iRet != TCL_OK) 
    {

        fprintf( stderr, "Unable to Initialize TK!\n" ); 
        return( iRet ); 

    } // end if

    return( TCL_OK ); 
}

void tkmain_exp() {
    // prototype for the initialization function 

    // declare an array for two strings 
    char *ppszArg[2];

    // allocate strings and set their contents 
    ppszArg[0] = (char *)malloc( sizeof( char ) * 12 ); 
    ppszArg[1] = (char *)malloc( sizeof( char ) * 12 ); 
    strcpy( ppszArg[0], "Hello World" );
    // 2nd arg is optional. or just create empty hello.tcl 
    // but if not, will enter tcl interact command line mode 
    strcpy( ppszArg[1], "./hello.tcl" );

    // the following call does not return 
    Tk_Main(2, ppszArg, InitProc ); 

}

