# Co-dfns Compiler

The Co-dfns project aims to provide a high-performance, high-reliability
compiler for a parallel extension of the Dyalog dfns programming language.
The dfns language is a functionally oriented, lexically scoped dialect of
APL. The Co-dfns language extends the dfns language to include explicit task
parallelism with implicit structures for synchronization and determinism. The
language is designed to enable rigorous formal analysis of programs to aid
in compiler optimization and programmer productivity, as well as in the
general reliability of the code itself.

Our mission is to deliver scalable APL programming to information and domain
experts across many fields, expanding the scope and capabilities of what
you can effectively accomplish with APL.

## Using the Compiler

The compiler is designed around a simple public interface that can be 
directly and simply used to replace or enhance traditional funtionality. 

### codfns.Fix

    Namespace ← Name codfns.Fix Namspace_Script

This is the primary interface into the compiler. It serves as a drop-in 
replacement for the ⎕FIX function. The `Name` should be some name that 
will serve as a prefix identifier for extra files that the compiler 
needs to generate in the build directory to create the namespace. It 
will compile the namespace and return the accessible functions as a 
Dyalog Namespace object.

### codfns.Cmp

    Exports ← Name codfns.Cmp Namespace_Script

This is used as a part of fixing, and allows you to run the compiler without 
building the namespace object. It will return a list of the exports of 
the namespace.

### codfns.MkNS

    Namespace ← Name codfns.MkNS Exports

This will take a list of exports and the compiler prefix name and fix a 
Dyalog namespace object with functions coming from the compiled code given 
by `Name`. 

### codfns.Xml

    String ← codfns.Xml AST

If you need to see the AST of the compiler, or work with it, this function 
allows you to serialize your code in the form of XML, rather than as a 
Namespace Script. It does require that you use either the parser or 
your own hacking skills to extract out a Co-dfns AST. 

### codfns.BSO

    Path ← codfns.BSO Name

Given the `Name` used as the left argument to `Fix`, it will give back the 
path to the primary Co-dfns compilation object. This is useful for doing 
manual linking into the compilation object using `⎕NA`.

### codfns.MKA

    Codfns_Array ← codfns.MKA Array

This allows you to manually obtain a pointer to a Co-dfns array created from 
a given Dyalog DWA Array. 

### codfns.EXA

    Array ← codfns.EXA Codfns_Array Type

Used to extract an array from Co-dfns. It will take a pointer to a Co-dfns 
array and the type of that array, and will free the array from the Co-dfns 
space and return that array as its result in the form of a normal Dyalog 
array.

### codfns.FREA

    {} ← codfns.FREA Codfns_Array

Frees a Co-dfns array pointer obtained from `MKA`. 

## Configuration

There are a few global settings that should be examined or set based on your 
local environment. The values given below are their default values.

### COMPILER

    COMPILER ← 'vsc'

This indicates the backend compiler to use. It should be one of the following 
names:

    Windows: vsc pgi
    Linux: gcc icc pgcc

### TEST∆COMPILERS

    TEST∆COMPILERS ← ⊂'vsc'

A vector of the backend compilers to test when running the test suite. See 
`COMPILERS` for valid options.

### DWA∆PATH

    DWA∆PATH ← 'dwa'

The path relative to your working directory indicating the location of the 
dwa package. Contact Dyalog, Ltd. for a copy of DWA for your platform. 

### BUILD∆PATH

    BUILD∆PATH ← 'build'

The path relative to your working directory where the compiler will store its 
intermediate files and the compiled objects. Should be a directory. 

### VISUAL∆STUDIO∆PATH

    VISUAL∆STUDIO∆PATH ←'C:\Program Files (x86)\Microsoft Visual Studio 14.0\'

The path to your Visual Studio installation. Make sure that you have installed 
the C++ compiler. 

### INTEL∆C∆PATH

    INTEL∆C∆PATH ← 'C:\Program Files (x86)\IntelSWTools\'
    INTEL∆C∆PATH ,← 'compilers_and_libraries_2016.0.110\windows\bin\'

The location of your `bin` directory for the Intel C Compiler. Needed to use 
Intel's C compiler on Windows. 

### PGI∆PATH

    PGI∆PATH ← 'C:\Program Files\PGI\win64\15.7\'

The path to your PGI installation on Windows. Needed if you wish to use PGI 
on Windows. You must have the OpenACC version of PGI. 

### VERSION

    Major Minor Patch ← VERSION

This is not designed to be set by the user, but indicates the version of the 
compiler. Version numbers are only valid as releases, and are subject to change 
during development in the repository. 

## Supporting the Project

We need your help! Please contact <arcfide@sacrideo.us> to learn how you
can support the project.

## Publications

[The Key to a Data Parallel Compiler](http://dl.acm.org/citation.cfm?id=2935331)

[Accelerating Information Experts Through Compiler Design](http://dl.acm.org/citation.cfm?id=2774968)

[Co-dfns: Ancient Language, Modern Compiler](http://dl.acm.org/citation.cfm?id=2627384)

[U11: Using Co-dfns to Accelerate APL Code](http://dyalog.com/user-meetings/dyalog15.htm)

[U07: Co-dfns Report: Performance and Reliability Prototyping](http://dyalog.com/user-meetings/dyalog14.htm)

[I04: Co-dfns Compiler](http://dyalog.com/user-meetings/dyalog13.htm)

