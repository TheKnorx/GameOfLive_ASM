# Game_of_Assembly <br> Implementation of Conway's Game of Life in NASM 64 x86 assembly

## Prerequisites: 
* Tool ImageMagick for creating a gif out of the created animation-pictures:<br>
`sudo apt install imagemagick`
* System running (debian-based) linux with Intel 64bit x86 architecture.

## Usage: 
Creating the animation with its animation pictures: `main <field-width> <field-height> <amount of generations>`<br>
Creating a gif from the created animation pictures: `make animation`<br>
To clean the folder from all executables, the build folder and any animation pictures, you may use `make clean`.<br>
One-liner example for creating the animation pictures and the gif file: `main 30 30 300 && make animation && make clean`<br>
<br>Until further notice, the start (first generation) of the animation is hardcoded into the code at `field_handler:configure_field`. 
A way of editing the start of the animation may be added in future implementations!

## Building:
To build the project use the provided Makefile with the command `make`.
The program runs only on Intel 64bit x86 architecture! Also it was only tested on Ubuntu and will most likely not work on Windows (- I mean why should it, its Windows. What do you expect?)

# Code Conventions:
## Function calls
* Every function call uses the `x84-64 System V ABI calling convention` for parameter passing, as well as for returning return values
* Every function is preceeded with at least one comment specifying the exact parameters to pass into and the exact return value it returns with in the form of `(<parameters>)[<return values>]` like so:<br>
  `(listOf[<C-type> <purpose-tag> @ <register/address>, ...])[<C-type> <purpose-tag> @ <register/address>]` <br>
  Additional comments ... yea. maybe
## Stack
* The stack of each function is aligned as `mod 16`. We do this by using this special stack alignment prolog:
  ```asm
  push    rbp
  mov     rbp, rsp
  and     rsp, -16
  ```
  \(For the haters and/or lovers of steal-clean assembly - i dont care and see x64 Assembly Language by Jeff Duntemann: chapter 12 - stack alignment)<br>
  (For the people who are missing the `enter` instruction, see [here](https://stackoverflow.com/a/5964507) why)

## Future ToDo's:
* ✅ Full replacement of glibc, including glibc functions, startup-code (`_start`, `__libc_start_main`, ...) and cleanup-code. <br>
* ✅ Implementation of custom stdout buffer management and improvement of already implemented mini-memory-allocator in `core.lib.asm`. <br>
* ❌ Implementation of a function capable of taking a user-input and set this as the start of the animation.  
