﻿ Z←FI;C;E;I;G;D;R;P
 Z←⍬ ⋄ R←CodfnsRuntime
 'ffi_get_type'⎕NA'U1 ',R,'|ffi_get_type P'
 'ffi_get_data_int'⎕NA R,'|ffi_get_data_int >I8[] P'
 'ffi_get_data_float'⎕NA R,'|ffi_get_data_float >F8[] P'
 'ffi_get_shape'⎕NA R,'|ffi_get_shape >U8[] P'
 'ffi_get_size'⎕NA'U8 ',R,'|ffi_get_size P'
 'ffi_get_rank'⎕NA'U2 ',R,'|ffi_get_rank P'
 'ffi_make_array_int'⎕NA'I ',R,'|ffi_make_array_int >P U2 U8 <U8[] <I8[]'
 'ffi_make_array_double'⎕NA'I ',R,'|ffi_make_array_double >P U2 U8 <U8[] <F8[]'
 'array_free'⎕NA R,'|array_free P'
 'cstring'⎕NA'libc.so.6|memcpy >C[] P P'
 'strlen'⎕NA'P libc.so.6|strlen P'
 'free'⎕NA'libc.so.6|free P'