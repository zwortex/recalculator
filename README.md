# recalculator
A scientific calculator in Red

## Installation

Download the script recalculator.red

The following assumes you have already retrieved the executable for running red scripts. If not, please go to [red download page](https://www.red-lang.org/p/download.html) and retrieve the last built version of Red for your current environment, and drop it in the same directory as this script.

**For running the script:** type

    red recalculator.red

**For compiling the script:** type either

    red -r -e -t Windows recalculator.red (for the standalone version)
    red -c -e -t Windows recalculator.red (for the version running against libRedRt.dll)

That should produce the executable recalculator.exe in the same directory.

*For other target than Windows*, please adapt the option -t as you wish. Note however that this 
script has only been tested on Windows 10 x64.

For further details on Red and how to run it, please refer to https://github.com/red/red

You may also load the script into a gui console that is already running. In such case, the 
recalculator will opens up automatically.
        
Once it is closed, you may start it again by typing the following command: 
```
recalculator/run
```

## Usage

Once the recalculator has been started, its usage is pretty straightforward. 
        
You may explore the following : standard operations ; extended fonctions in the option menus ;
computations may be stacked/unstacked, modified or combined using variables (#1, #2...) ;
undo/redo ; clear either a character, a line or the entire stack ; various parenthesis.
