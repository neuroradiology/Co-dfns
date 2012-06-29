\def\title{HPAPL: Runtime}
\def\topofcontents{\null\vfill
  \centerline{\titlefont The HPAPL Runtime Environment}
  \vskip 15pt
  \centerline{(Version 1.0)}
  \vfill}
\def\botofcontents{\vfill
\noindent
Copyright $\copyright$ 2012 Aaron W. Hsu $\.{arcfide@@sacrideo.us}$
\smallskip\noindent
Permission to use, copy, modify, and distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.
\smallskip\noindent
THE SOFTWARE IS PROVIDED ``AS IS'' AND THE AUTHOR DISCLAIMS ALL
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
}

@* Introduction. You are reading the source code that implements 
the runtime environment for HPAPL. This code deals especially with 
the low-level details of the semantics of HPAPL programs, providing 
an API for the HPAPL compiler to target. It is fairly involved, 
because I want to isolate most of the complexity of the nitty 
details to the C compiler, and away from the main compiler, so that 
the main compiler's whole focus is on higher-level optimizations.
Thus, this runtime is in charge of datastructures, calling 
conventions, function abstractions, higher-order programming, 
primitive APL functions, memory management, and most every other 
detail of implementation. The program can be divided up mostly 
into the following sections:

@p
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

@h

@<Runtime error reporting@>@;
@<Primary data structures@>@;
@<Utility functions@>@;
@<Memory management functions@>@;
@<Scalar APL functions@>@;
@<Non-scalar APL functions@>@;
@<APL Operators@>@;

@ The HPAPL at its core has two data types, functions and arrays. 
Functions as implemented in the runtime are first-class objects, but 
arrays cannot contain functions, which limits the areas where 
functions may be used. Arrays themselves may have either integers, 
reals, or characters in them. They are multi-dimensional and 
follow standard APL practices. We will be implementing most of 
the APL primitives in the runtime directly, but some will be written 
in terms of the others. This is a design decision over having some 
of the primitives written in the higher-level HPAPL language, 
rather than in the language of the runtime. Scalar functions are 
those that operate element-wise over two arrays, and non-scalar 
functions are everything else.  Operators are those class of 
functions that can take other functions as their arguments.

@ We do have one utility function that we use to store the version 
number of the runtime. This prints out a string representing the 
runtime version from the |runtime_ver| variable.

@p
float ver = 1.0;

void
print_version(void)
{
	printf("HPAPL Runtime Version (%f)\n", ver);
	printf("Copyright (c) 2012 Aaron W. Hsu\n");
}

@ This concludes the main introductions, we can now proceed to the 
details of implementing the runtime.

@* Data structures.  We must implement two main data structures: 
arrays and functions.  Arrays are the most used, and we have a few 
requirements that drive our design. First, we want them to be as fast as 
possible, but we also want to be able to decouple the core array 
structure from the data areas where we store the elements. This 
frees us to potentially make use of faster memory allocation 
functions, segmented heaps, as well as shared data regions between 
multiple arrays. In the end, it is a more flexible solution. 
We expect that most of the array headers will be stack allocated 
and that their allocations will be automatic. We use a static 
shape array to store the shape information so that we do not 
have to worry about managing that. In practice, noble arrays are 
rare, and we can do with having only a reasonably large number of 
them. There is some question as to the size that we allocate for 
each dimension. Specifically, the number of elements that are 
needed for any given array of shape $s$ whose rank is $r$ and 
where $s_i$ is the dimension length of the $i$th dimension of 
the array, the number of elements that we need is thus:

$$\prod_{i=0}^{r}s_i$$

\noindent Of course, we have a theoretical limit on the 
number of elements that we can have and reference, and we 
would want a vector (rank 1 array) to be able to have that many 
elements as well as arrays of other rank. This implies that our 
space that we allocate for a single dimension must be capable 
of addressing our theoretical limit on our elements, but this 
also means that we could create an invalid array that references 
more elements than we have space to store. However, we can 
actually have valid arrays like this that we can implement if 
they have patterns that allow us to compress their element 
representations, such as repeating arrays or arrays whose 
elements are all the same.

Because of the above considerations, we make the arrays 
dimensions |unsigned int| in size. We use the unsigned feature 
because we do not have negative shapes. This gives us all the 
range of |unsigned int| save one, so we have a maximum number 
of elements for an array fixed at |UINT_MAX - 1|, where 
|UINT_MAX| is used to indicate that a particular dimension is not
in use. For future ease of transition to larger sizes we make sure 
to define |SHAPE_END| for use instead of |UINT_MAX|. The shape 
of an array is then the non-negative elements of the shape 
field up to but not including the first element whose value is 
|SHAPE_END|. We expect all the other values to be |SHAPE_END| 
after that. While using |unsigned int| is relatively small for the
number of elements that we can potentially access on a 64-bit 
machine, it is big enough at the moment, and we can scale this 
up without cause for alarm in the future. We do not limit the 
size of the data regions like this though, and we use an 
appropriate |size_t| variable to hold the size of the data 
region. This gives us the following fields for our arrays:

\medskip
\itemitem{|shape|} A static array of length |MAXRANK| whose 
elements are all |unsigned int| values;
\itemitem{|size|} The number of bytes allocated for the region 
pointed to by |data|;
\itemitem{|data|} A pointer to a region of memory containing 
the elements in row-major order; and finally,
\itemitem{|type|} An enumeration indicating the type of elements
in the array.

\medskip\noindent This leads us to the following |typedef| 
and definitions. We have a maximum array rank of 32. 

@d MAXRANK 32
@d SHAPE_END UINT_MAX
@s AplType int

@<Primary data structures@>=
@<Define AplType@>@;
struct apl_array {
	unsigned int shape[MAXRANK];
	AplType type;
	size_t size;
	void *data;
};
typedef struct apl_array AplArray;

@ We have three main types of values that we can have, and to indicate 
which one that we use, we setup an enumeration. We have one other 
value |UNSET| that indicates that nothing has been done with the array 
yet. Our |INT| type is the largest integer type that we have in C89
which happens to be |long|. On my system this is a 64-bit integer, 
but this is only required to be a 32-bit integer. I think this is a 
reasonable choice to get decent performance on most systems. The 
|REAL| type is a |double|, since I want to have as much precision in 
my single floating point type as I can.  Finally, I have |CHAR| set 
to |wchar_t| since we are dealing with wide characters throughout;
this is APL afterall.

@<Define AplType@>=
enum apl_type { INT, REAL, CHAR, UNSET };
typedef enum apl_type AplType;
typedef long AplInt;
typedef double AplReal;
typedef wchar_t AplChar;

@ There are a few very useful functions relating to arrays that 
we should talk about. The first is a way to get the size based on 
the contents of the |shape| array.
The size can be expressed as follows:

$$\prod_{i=0}^{r}s_i$$

\noindent Where $r$ is the |rank| of the array, and $s$ is the 
shape array. Specifically, it is the product of the dimensions 
of the array.

@<Utility functions@>=
int size(AplArray *array) 
{
	int i, res;
	unsigned int *shp;

	res = 1;
	shp = array->shape;

	for (i = 0; i < MAXRANK; i++, shp++) {
		if (SHAPE_END == *shp) break;
		else res *= *shp;
	}
	
	return res;
}

@ Next, we very often want to talk about the rank of an array, so 
we encapsulate that up into a function.
Specifically, if we define 
$s = \{x\in \hbox{|array->shape|} \mid x\neq |SHAPE_END|\}$, 
then |rank| should be the size or cardinality of $s$.

@<Utility functions@>=
short rank(AplArray *array) 
{
	short i, rnk;
	unsigned int *shp;

	rnk = 0;
	shp = array->shape;

	for(i = 0; i < MAXRANK; i++) {
		if (SHAPE_END == *shp++) break;
		else rnk++;
	}

	return rnk;
}

@ Finally, it's very helpful at times to be able to talk about the 
product of an integer array's ravel. Basically, we often want to 
compute the product when we are using the array as a reshape value 
for another array or the like. For this we assume that the array 
that we are given is an integer array, and then we get to work.
If $a$ is the ravel of |array| and $a_i$ is the $i$th element in 
that ravel, then |product| should compute the following:

$$\prod_{i=0}^{size(array)}a_i$$

\noindent That is, the product of all the elements in the array.

@<Utility functions@>=
unsigned int product(AplArray *array)
{
	int i, len;
	int *data;
	unsigned int prod;

	prod = 1;
	len = size(array);
	data = array->data;

	for (i = 0; i < len; i++) prod *= *data++;

	return prod;
}

@ Let's proceed to functions. In HPAPL, a function is either an 
operator or a normal function.  At the higher level language, 
we can distinguish these by asking whether a function has 
$\alpha\alpha$ or $\omega\omega$ as a free variable or not. 
We make no distinction between functions which take functions 
and normal functions at the runtime level. Instead, unless 
optimized away, all functions have an explicit, possibly empty 
closure allocated for them. This closure is what is passed 
around to primitive operators and the like. Thus, all functions 
have the same signature as their C function elements.

@s AplCodePtr int
@s AplFunction int

@<Primary data structures@>=
@<Define |AplFunction| type@>@;
typedef void (*AplCodePtr)(AplArray *res,
    AplArray *, AplArray *, AplFunction *);

@ Initializing an array is just a matter of setting up all the 
values to suitable defaults before we do any allocations. This 
should be done to ensure that everything is nice and clean. 
This function does not do any allocation, but simply sets some 
fields.  See the section further down on memory management 
for functions that allocate space for arrays and the like.

@<Utility functions@>=
void init_array(AplArray *array)
{
	int i;
	unsigned int *shp;

	shp = array->shape;
	array->type = UNSET;
	array->size = 0;
	array->data = NULL;

	for (i = 0; i < MAXRANK; i++) *shp++ = SHAPE_END;
}

@ So, what is an |AplFunction| anyways. It is a structure to 
contain all of the free variables in an APL function that might 
come in other than what the actual arguments to an APL function 
would be. This includes the functions that an operator might 
receive. This means that it needs to have an environment in 
it to store there free variable references, and also pointers 
for the $\alpha\alpha$ and $\omega\omega$ operator variables 
explicitly. However, since we are dealing with a closure here, 
it needs to be more than just the environment. In most cases, 
we will often pass around only an |AplFunction| value, and 
not the actual |AplCodePtr| value.  This means that we need to 
have a pointer to the code that expects the closure as well.

@s AplOperand int
@s AplOperand int

@<Define |AplFunction| type@>=
struct apl_function {
	void (*code)(AplArray *, AplArray *, AplArray *,
	    struct apl_function *);
	union apl_operand *lop; /* The $\alpha\alpha$ variable */
	union apl_operand *rop; /* The $\omega\omega$ variable */
	union apl_operand *env; /* All other free variables */
};
typedef struct apl_function AplFunction;

@ To actually use a closure we need to be able to apply it to 
arguments. This is done through a simple macro.
The arguments are all expected to be pointers to their appropriate
data types.

@d apply(fun, res, lft, rgt) ((fun)->code)(&res, lft, rgt, fun)

@ We have not yet explained why we use |AplOperand| for the |lop| 
and |rop| variables, which correspond to $\alpha\alpha$ and 
$\omega\omega$ variables in a function. In APL, an operators 
left and right operands can be either functions or arrays. We may 
need to allow both even in the same operator, so we have a type 
which can be either the one or the other. We implement this with 
a union, because in practice, we will know at the time that we 
use an operand, how it is to be used: either as a function or as 
an array. This means that we do not need to have a type tag as 
we do with the |AplArray| type.

@<Primary data structures@>=
union apl_operand {
	AplArray array;
	AplFunction function;
};
typedef union apl_operand AplOperand;

@ We are about done with the work on the primary data structures, 
so we should take some time to get all of the other basic array 
utilities out of the way. Let's focus specifically on those that 
we might find generally useful, but that do not deal with 
any allocation explicitly. To start us off, we'll deal with 
shapes.  We may want to know whether a given array is scalar, 
vector, matrix, or noble. These macros can help with that.

@d is_scalar(array) (0 == rank(array))
@d is_vector(array) (1 == rank(array))
@d is_matrix(array) (2 == rank(array))
@d is_noble(array)  (2 < rank(array))

@ It is also useful to be able to grab the shape from one array 
and put it into another. This is the main header information that 
does not involve allocation. 

@<Utility functions@>=
void copy_shape(AplArray *dst, AplArray *src) 
{
	short i;
	unsigned int *dstshp, *srcshp;
	dstshp = dst->shape;
	srcshp = src->shape;
	for (i = 0; i < MAXRANK; i++) *dstshp++ = *srcshp++;
}

@ Note, we could also talk about the |type| field, which is another 
field that does not relate directly to the heap-allocated regions 
of the array, but in this case, it's no good, because |type| is 
actually indirectly responsible, and there are not many useful 
functions that we would want to use |type| in that did not 
also involve allocation.

@ Finally, before we proceed to the section on memory management, we 
should talk about initializing closures.  In this case, a closure 
will normally be something that we know the size of statically, 
since we will know how many variables are free in the function. We 
want to make it convenient to setup all those values based on local
elements, so we have a choice of either accepting those values 
directly with a variable length argument list, or forcing the user 
of the runtime (the compiler) to give us an array.  In this case, 
because the number of free variables is expected to be small most of 
the time, I think it is safe to use variable length argument lists 
for convenience instead of forcing the pollution of the namespace 
with an explicit environment list. We assume that we have an 
|AplFunction| structure pointer that is already allocated for the 
correct number of free variables that we have.

@<Utility functions@>=
void init_function(AplFunction *fun, AplCodePtr code, 
    AplOperand *lop, AplOperand *rop, ...)
{
	va_list ap;
	AplOperand *env, *var;
	fun->code = code;
	fun->lop = lop;
	fun->rop = rop;
	env = fun->env;
	va_start(ap, rop);
	while (NULL != (var = va_arg(ap, AplOperand *))) {
		env = var; env++;
	}
	va_end(ap);
}

@* Memory management functions. This section is meant to deal 
specifically with controlling and allocating space for arrays and 
other sorts of things that can be grouped under the ``memory 
management'' moniker. Mostly, this means allocating and freeing 
arrays and function closures in useful, easy ways. Function closures 
are the easiest, but I want to take a moment to discuss the general 
idea behind the |AplArray| structure and how it should be used.

In general, I expect that most allocations of |AplArray| objects 
should be automatic.  That is, most of the time, you know that you 
need one, and you will allocate it locally using stack allocations 
or some other form that allows for automatic memory management. 
This leaves only the |array->data| field as something that needs 
to be managed entirely and almost always on the heap. I imagine 
that if you have a small function with a small array you could 
get by with allocating the |data| element on the stack or 
automatically as well, but this would likely create problems 
unless you are absolutely sure of the lifetime of the array. 
In the future, we might also want to enable some sort of sharing 
of array data structures, to enable access of multiple array 
headers into the same region for shared access to elements. 
This involves a sort of copy on write semantics. If an array 
|data| region is not heap-allocated, we could have real problems 
if a region is shared with an array that will outlive the local 
scope of the allocation. In short, always use the memory 
allocation functions here for allocating and resizing arrays 
|data| regions, though it is okay and preferred to stack 
allocate |AplArray| structures unless you explicitely want 
to avoid that for some reason.

With that out of the way, let's talk a bit more about closures, 
which are the easier thing to work with.  When we allocate 
a closure, we need to provide values for the $\alpha\alpha$ 
and $\omega\omega$ variables, and potentially also for the 
rest of the free variables. However, we normally know exactly 
how many free variables a function's code body is going to need 
at compile time, and so we can statically allocate those.  
Moreover, it is never possible for a function to be returned 
from another function, just allocated, and this means that we 
can rely on no functions above the current call stack needing 
access to the free variables or the like. Indeed, closures, 
in most cases, should be able to be allocated almost entirely 
statically or automatically.

@ The most common situation that we encounter that requires good 
memory management abstraction is the handling of the |array->data| 
field. Normally, we have an array that has been automatically 
allocated for which we now need to make enough space to store
elements of a particular type. Assuming that we already know how 
the shape of the array looks, we know how many array elements that 
we ultimately need. All we need explicitely is the type of the 
elements that are going to be stored there. Ideally speaking, 
we want to reuse space that has already been allocated to the array 
if there is enough room to store the elements that we need. 
We provide two different allocators, the first, |alloc_array| for 
when we do not care to keep the old contents of the array.

@<Memory management functions@>=
void alloc_array(AplArray *array, AplType type)
{
	size_t dsize;
	void *data;
	data = array->data;
	dsize = type_size(type) * size(array);
	if (NULL == data || dsize > array->size) {
		free(data);
		data = malloc(dsize);
		@<Verify that |data| allocation succeeded@>@;
	}
	array->data = data;
	array->size = dsize;
}

@ There are times when we may want to preserve the contenst of an 
array as we resize it to hold more elements or the like. To handle 
these situations, we provide the |realloc_array| function that is 
basically the same as the |alloc_array| function except that it 
guarantees that the contents of the array will be the same up 
to the |size(array)| of the |array|. 

@<Memory management functions@>=
void realloc_array(AplArray *array, AplType type)
{
	size_t dsize;
	void *data;
	data = array->data;
	dsize = type_size(type) * size(array);
	if (NULL == data || dsize > array->size) {
		data = realloc(data, dsize);
		@<Verify that |data| alloc...@>@;
	}
	array->data = data;
	array->size = dsize;
}

@ In both of the above functions we want to check that the allocation
succeeds or that we trigger an error if it does not. We encapsulate 
that into a single place here.

@<Verify that |data| allocation succeeded@>=
if (NULL == data) {
	perror("array_[re]alloc()");
	apl_error(APLERR_MALLOC);
	exit(APLERR_MALLOC);
}

@ We also have a little helper utility that we use in both of the 
above functions to determin the size of a given type.

@<Utility functions@>=
size_t type_size(AplType type) 
{
	switch(type) {
	case INT: return sizeof(AplInt);
	case REAL: return sizeof(AplReal);
	case CHAR: return sizeof(AplChar);
	default: return 0;
	}
}

@ It is extremely useful to be able to copy the contents of one 
array into another. This is a simple function, and we do some 
allocation on the destination to ensure that we have enough space, 
but otherwise, it is a straightforward function.
It is an interesting note that we do not copy the entire |src->data| 
to the destination array. Instead, we copy only what is needed to 
store |size(dst)| elements worth of the data, because that is all 
that is needed by the destination array.  It is presumed that the 
data beyond this point is probably junk.

@<Memory management functions@>=
void copy_array(AplArray *dst, AplArray *src) 
{
	if (dst == src) return;

	copy_shape(dst, src);
	alloc_array(dst, src->type);
	memcpy(dst->data, src->data, dst->size);
}

@* Primitive scalar function. Now we come to the fun part, where we 
actually start implementing some real APL functions. The first and 
most obvious one to implement is the |plus| function, and it will 
show how we implement most functions.  We try to follow the same 
patter of coding throughout to maximize the amount of code that we 
can reuse. Basically, all scalar functions have an operation 
that they perform over all elements. Given a range, an operation, 
and the data, we can abstract over the basic scalar process. 
We use macros so that we are not sensitive to the types, and we 
define two macros, one for the monadic operations, and one for 
the dyadic operations.

@d SCAMONLP(op, restyp, type, next) {
	unsigned int i, rng;
	restype *resd; type *data;
	rng = size(res);
	resd = (restype) res->data;
	data = (type) rgt->data;
	for (i = 0; i < rng; i++, resd++, next(data))
		*resd = op(*data);
}
@d SCADYALP(op, restyp, lfttyp, rgttyp, lftnxt, rgtnxt) {
	unsigned int i, rng;
	restyp *resd; lfttyp *lftd; rgttyp *rgtd;
	resd = res->data;
	lftd = lft->data;
	rgtd = rgt->data;
	rng = size(res);
	for (i = 0; i < rng; i++, resd++, lftnxt(lftd), rgtnxt(rgtd))
		*resd = op(*lftd, *rgtd);
}

@ As you can see, a scalar function could receive scalar arguments 
on either side that must be distributed to the other array if 
that array is of a non-scalar shape. This is why we have the 
|next|, |lftnxt|, and |rgtnxt| operations in our macros, as they 
abstract the operations necessary to iterate down the buffer.
In our case, we need only two to represent all of the types of 
iteration that we may do with scalar functions. One of them 
is a no-op for iterating over a single scalar, and the other 
iterates down the array elements one at a time.

@d scalar_next(array) array
@d array_next(array) array++

@ Before we can get to the specifics of implementing the main 
scalar functions, there is still one more abstraction with macros 
that I want to make. Specifically, we need to be careful about 
scalar functions that operate on themselves. 
In principle, we can do in-place updates when we have sharing. 
Because all scalar functions have the same basic set of operations, 
we can abstract away the main elements outside of their main 
function that they compute to handle the grunge work for all 
scalar functions in one place. We divide the possible sharing 
cases thusly:

\medskip
\item{1)} {\it All arguments the same.} In this case, all 
of the arguments are the same. We know that the input types 
are the same and that the input arrays are of the exact same 
shape. We cannot in general guarantee that the type of the 
output array is going to be the same as the input array, 
however, which means that we may potentially have to 
store contents into a temporary array and then replace the 
old contents with the new when we are done with the work.
If we can assert that the output type uses less than or equal 
space to the space conumed by the input type, then we can do 
an in-place update.
\item{2)} {\it All inputs are the same.} In this case, 
all the inputs are the same, but the output is a different 
array. This is the general case when we are dealing with 
monadic functions, but when we are dealing with dyadic 
function, we have to be careful: we are in danger of iterating 
too fast over an array if we na\"ively use the iterators 
without first making sure that they are not the same object. 
See the way that the |SCADYALP| macro works to see this. 
The solution is to use a no-op scalar iterator for one of 
the arguments instead. We may also need to do subtle things 
with the shape and allocation operations, which we discuss 
more in the implementation of |SCALAR_PRIM_CASE2|. 
\item{3)} {\it Left or right argument is the same as 
the result.} In this case, which is the same as case 1 
in the monadic case, we have one or the other of the 
inputs, but not both, equal to the result array in the 
sense that they are the same object in memory. 
This is probably among the most interesting and subtle of the 
cases when it comes to allocation. We have to handle both the 
shared object relationship and ensuring that overwrites will not 
occur when we do not want them, but also with the potential for 
scalar distribution, because the two arguments are different. 
We discuss this in more detail when we implement it further on.
\item{4)} Finally, then general case is the one where we have 
none of the inputs as equal to one another. In this case, 
we must do all the checking and allocating for the result 
array, but we do not need to do any modification of the 
inputs. The result array will be the larger of the shapes, 
assuming that one of them is a scalar and the other is not.
Otherwise the shape of the result array will be the same 
as the shape of the inputs, which must be the same. 
\medskip

\noindent
The job of each case is to make sure that the output 
array is allocated correctly, and that anything that needs to be 
done on that front is done. 

@d SCAPRIMDYA(op, ztv, zt, lt, rt)
	if (lft == rgt) {
		if (res == lft) {
			SCALAR_PRIM_CASE1(op, ztv, zt, lt, rt)@;
		} else {
			SCALAR_PRIM_CASE2(op, ztv, zt, lt, rt)@;
		}
	} else if (res == lft) {
		SCALAR_PRIM_CASE3A(op, ztv, zt, lt, rt)@;
	} else if (res == rgt) {
		SCALAR_PRIM_CASE3B(op, ztv, zt, lt, rt)@;
	} else {
		SCALAR_PRIM_CASE4(op, ztv, zt, lt, rt)@;
	}

@ In the first case, where all of the inputs and the return array 
are the same object, we know the shape and sizes of everything will 
be the same, so we do not have to check for that. However, we do 
need to deal with the situation where we may a different output 
type than the input types. In this case, if the output type is 
of a size larger than the input type, it is not safe to do an 
inplace computation, since the larger values will overwrite the 
contents of the next element in the computation. This does not 
occur with the output type is smaller in size than the input 
type, so we can get away with doing an in-place update then. 
When the output type is larger, and it is not safe to do 
the in-place update, we will leave the main buffers alone, 
as they already have good input values, and we will allocate 
a new result array of the right size and shape. We can then 
store the outputs into that, finally replacing the contents 
of the old array and freeing the old buffers when we are done.

@d SCALAR_PRIM_CASE1(op, ztv, zt, lt, rt)
if (sizeof (zt) > sizeof (lt)) {
	AplArray tmp;
	init_array(&tmp);
	copy_shape(&tmp, rgt);
	alloc_array(&tmp, ztv);
	res = &tmp;
	SCADYALP(op, zt, lt, rt, array_next, scalar_next)@;
	free(rgt->data);
	rgt->size = res->size;
	rgt->data = res->data;
} else {
	SCADYALP(op, zt, lt, rt, scalar_next, scalar_next)@;
}

@ In the second case, we have the inputs being the same, but the 
output being an entirely different beast. This gives us the same 
guarantees that allow us to avoid checking on the input shapes 
for scalar distribution, but it also means that we need to always 
do an allocation for the result array, as well as always copying 
the shape into the result array, which will be the shape of either 
of the input arguments, since they are the same. 

@d SCALAR_PRIM_CASE2(op, ztv, zt, lt, rt)
copy_shape(res, rgt);
alloc_array(res, ztv);
SCADYALP(op, zt, lt, rt, array_next, scalar_next)@;

@ In the third case, either the left or the right inputs, but not 
both is equal to the result array. The process for handling the one 
is the exact same as handling the other case, just with some arguments 
swapped around. In both of these cases, we need to check the shapes 
of the two inputs to see if they are the same or if they are different. 
If they are different, then we need to check whether the input 
equal to the result is the scalar case. If that is true, then the 
result array will not be sufficient to hold the contents, and we need 
to separate out the scalar input from the result. In the other case, 
we still must check to make sure that the output type is not bigger 
than the input types, and if it is, we need to make accomodations 
for that, by scaling up the output array. Thus, there are two cases 
where we need to allocate a temporary output array, the one when 
we have a scalar result and a non-scalar input, and the other 
when we have a result type that consumes more space than the input 
type.

The first sub-case $a$ is the case when |res == lft|. 

@d TEMPRES(array, ztv)
	AplArray tmp;
	init_array(&tmp);
	copy_array(&tmp, array);
	alloc_array(&tmp, ztv);
	res = &tmp;
@d REPLACEDATA(dst, src)
	free(dst->data);
	dst->size = src->size;
	dst->data = src->data;

@d SCALAR_PRIM_CASE3A(op, ztv, zt, lt, rt)
short lftrnk, rgtrnk;
lftrnk = rank(lft); rgtrnk = rank(rgt);
if (lftrnk != rgtrnk) {
	if (0 == lftrnk) {
		TEMPRES(rgt, ztv)@;
		SCADYALP(op, zt, lt, rt, scalar_next, array_next)@;
		REPLACEDATA(lft, res)@;
	} else if (sizeof (zt) > sizeof (lt)) {
		TEMPRES(lft, ztv)@;
		SCADYALP(op, zt, lt, rt, array_next, scalar_next)@;
		REPLACEDATA(lft, res)@;
	} else {
		SCADYALP(op, zt, lt, rt, scalar_next, scalar_next)@;
	}
} else {
	if (sizeof (zt) > sizeof (lt)) {
		TEMPRES(lft, ztv)@;
		SCADYALP(op, zt, lt, rt, array_next, array_next)@;
		REPLACEDATA(lft, res)@;
	} else {
		SCADYALP(op, zt, lt, rt, scalar_next, array_next)@;
	}
}

@ The second sub-case of case 3, $b$, is the same as sub-case $a$ 
but with |res == rgt| instead.

@d SCALAR_PRIM_CASE3B(op, ztv, zt, lt, rt)
short lftrnk, rgtrnk;
lftrnk = rank(lft); rgtrnk = rank(rgt);
if (lftrnk != rgtrnk) {
	if (0 == rgtrnk) {
		TEMPRES(lft, ztv)@;
		SCADYALP(op, zt, lt, rt, array_next, scalar_next)@;
		REPLACEDATA(rgt, res)@;
	} else if (sizeof (zt) > sizeof (rt)) {
		TEMPRES(rgt, ztv)@;
		SCADYALP(op, zt, lt, rt, scalar_next, array_next)@;
		REPLACEDATA(rgt, res)@;
	} else {
		SCADYALP(op, zt, lt, rt, scalar_next, scalar_next)@;
	}
} else {
	if (sizeof (zt) > sizeof (rt)) {
		TEMPRES(rgt, ztv)@;
		SCADYALP(op, zt, lt, rt, array_next, array_next)@;
		REPLACEDATA(rgt, res)@;
	} else {
		SCADYALP(op, zt, lt, rt, array_next, scalar_next)@;
	}
}

@ The fourth and most general case is when none of the inputs are 
the same. In this case, we need to check on the shapes of the 
inputs because we do not know if any of them is the same, and we 
also need to do all of the general allocation for the result array
once we have the right shape. In some ways this is the most simple 
case because we do not have to consider the effects of overlapping 
reads and writes to the buffers.

@d SCALAR_PRIM_CASE4(op, ztv, zt, lt, rt)
short lftrnk, rgtrnk;
lftrnk = rank(lft); rgtrnk = rank(rgt);
if (lftrnk == rgtrnk) {
	copy_shape(res, rgt);
	alloc_array(res, ztv);
	SCADYALP(op, zt, lt, rt, array_next, array_next)@;
} else if (0 == lftrnk) {
	copy_shape(res, rgt);
	alloc_array(res, ztv);
	SCADYALP(op, zt, lt, rt, scalar_next, array_next)@;
} else if (0 == rgtrnk) {
	copy_shape(res, lft);
	alloc_array(res, ztv);
	SCADYALP(op, zt, lt, rt, array_next, scalar_next)@;
}

@*1 Implementing Plus and Identity.
Now that we have covered the basic 
scalar abstractions, let's take a whack at
trying to implement the more specific functions, namely, the |plus| 
function. We need to define a few things. Firstly, we need to know 
the domain on which |plus| operates. In this case, it is a dyadic 
function which works only in |INT| and |REAL| types. The resulting 
type of the computation should be determined by the largest 
input type, which means that two |INT| types are |INT| results, 
but everything else is a |REAL|. So, firstly, we need the plus
macro for our operation, and then we can define the main 
|plus| function.

@d plus_op(l, r) (l + r)

@<Scalar APL functions@>=
void plus(AplArray *res, AplArray *lft, AplArray *rgt, AplFunction *env)
{
	AplType lfttyp, rgttyp;
	lfttyp = lft->type; rgttyp = rgt->type;
	if (INT == lfttyp) {
		if (INT == rgttyp) {
			SCAPRIMDYA(plus_op, INT, AplInt, AplInt, AplInt)
		} else if (REAL == rgttyp) {
			SCAPRIMDYA(plus_op, REAL, AplReal, AplInt, AplReal)
		} else {
			apl_error(APLERR_DOMAIN);
			exit(APLERR_DOMAIN);
		}
	} else if (REAL == lfttyp) {
		if (INT == rgttyp) {
			SCAPRIMDYA(plus_op, REAL, AplReal, AplReal, AplInt)
		} else if (REAL == rgttyp) {
			SCAPRIMDYA(plus_op, REAL, AplReal, AplReal, AplReal)
		} else {
			apl_error(APLERR_DOMAIN);
			exit(APLERR_DOMAIN);
		}
	} else {
		apl_error(APLERR_DOMAIN);
		exit(APLERR_DOMAIN);
	}
}

@ The |identity| function is the monadic form of the $+$ function 
in APL. In this case, since we know that it is the identity function, 
we can avoid a number of the overheads of the generic looping 
constructs in the case when we know the relationship between the 
single argument and its result array. Otherwise, a simple 
|memcpy()| suffices instead of a loop.

@<Scalar APL functions@>=
void identity(AplArray *res, AplArray *rgt, AplFunction *env)
{
	if (res == rgt) return;
	else copy_array(res, rgt);
}

@* Non-scalar primitive function. In this section we will deal with 
the class of functions that are non-scalar. These do not have the 
nice, neat, and regular properties that the scalar functions have, 
and so we cannot abstract away all of those operations into a common 
set of macros. Fortunately, there are not quite so many of these 
functions, and they are quite fun and interesting, so let's look 
at them.

@*1 The Iota function. This is the classic $\iota$ function that 
is so fundamental to APL. However, we are going to implement this a 
bit more like the way that iota is treated in ``A Mathematics of 
Arrays.'' We do not have nested arrays in HPAPL, which is different 
than some other APL systems, like APL2, Dyalog, or APLX, which 
all have nested arrays. This is a philosophical consideration 
as much as anything, but it leads to interesting things when 
we call Iota with non-scalar vectors whose size is greater than 
one. Fortunately, the basic iota is still relatively straight 
forward, so we will begin there and discuss the details of the 
more complicated setup next.

@<Non-scalar APL functions@>=
void index(AplArray *res, AplArray *rgt, AplFunction *env)
{
	short rnk;
	unsigned int siz;
	if (INT != rgt->type) {
		apl_error(APLERR_DOMAIN);
		exit(APLERR_DOMAIN);
	}
	rnk = rank(rgt);
	siz = size(rgt);
	if (0 == rnk || (1 == rnk && 1 == siz)) {
		int i;
		AplInt *data;
		res->shape[0] = *((AplInt *)rgt->data);
		alloc_array(res, INT);
		for (i = 0, data = res->data; i < res->shape[0]; i++)
			*data++ = i;
	} else {
		@<Compute indexes of non-scalar vector@>@;
	}
}

@ Now let's consider the main case of the Iota (properly, then |index|) 
function.  In this case, we have a vector $v$ of some $n$ elements 
where we want to return a matrix where each row is a valid index into 
an array of shape $v$. These indexes should be in row-major order.
Now, the way that we compute this set is to progress in order down 
the data array and compute the function directly. We have one 
helper array $p$ where, if $r$ is the size of the incoming vector, 
$p_r=1$ and $p_i = \prod_{j=i+1}^{r}v_j$ where $v_j$ is the $j$th 
element of the incoming input array |rgt|. Thus, $p$ is the 
``places'' array. For example, in an array of three 10's, the 
vector $p$ would be $\{100, 10, 1\}$. We use this to then compute 
the value of each cell in the matrix according to the following 
formula:

$$a_{i,j} = \lfloor i/p_{j}\rfloor\bmod v_j$$

\noindent To make this more clear, we can think about our result 
array as being a matrix of numbers from $0$ to the |product(rgt)| 
where each number is represented from lowest to highest, one 
per row. Each column is one digit of the number represented in 
a base |rgt|, that is, a base where each place is one of the 
dimensions of the array we are indexing into. The function above 
computes one of these digits. In our implementation, we use 
a doubly nested loop to give us the $i$ and $j$ elements.

@<Compute indexes of non-scalar vector@>=
unsigned int *p, prod;
int i, j;
AplInt *v, *a;

v = rgt->data;
a = res->data;
prod = product(rgt);
@<Compute |p| vector@>@;
for (i = 0; i < prod; i++)
	for (j = 0; j < siz; j++)
		*a++ = (i / p[j]) % v[j];
free(p);

@ Computing the product vector means that we compute the product 
of the elements in |rgt| after the current index that we are 
considering. The easiest way to do this is to start at the end 
and move towards the front.

@<Compute |p| vector@>=
p = malloc(siz * sizeof(AplInt));
if (NULL == p) {
	apl_error(APLERR_MALLOC);
	exit(APLERR_MALLOC);
}
p[siz - 1] = 1;
for (i = siz - 1; i > 0; i--)
	p[i-1] = p[i] * v[i];

@* APL Operators and their implementation.
APL operators are functions that return other functions. In the 
end, there is always some specific function that they compute, but 
that computation is parameterized by one or two input functions, 
or possibly a combination of functions and arrays. It is helpful to 
imagine first how an operator might be used in a piece of code.
In the code below, we implement the equivalent to the following 
APL program:

$$X+\ddot{ }\ X\gets\iota 100$$

Here is an example:

@<Example use of an APL operator@>=
AplFunction myeach, myplus;
AplArray z, a;
alloc_array(&a, INT);
a.data[0] = 100;
index(&a, &a, NULL);
init_function(&myplus, plus, NULL, NULL, NULL);
init_function(&myeach, each, (AplOperand *) &myplus, NULL, NULL);
apply(&myeach, &z, &a, &a);

@ As you can see in the above example, we must create a closure 
for every function that we intend to pass to an operator, and 
we create a closure for each operator whose function instance we 
want to use. This means that we need to use apply with those
functions that we create.  We could probably have gotten away 
with just using the |each| call directly here, because the each 
operator is a primitive, and sometimes that will be preferrable. 
Thus, we could have eliminated the indirection of the application 
by calling |each| directly. You can see this here below.

@<Trading out the application@>=
each(&z, &a, &a, &myeach);

@ Like the non-scalar APL functions, each APL operator is slightly 
unique, and requires its own implementation. This means that there 
is no special abstraction to use in each operator to share the 
work. We must implement each one directly. Let's proceed with each 
operator in turn through the rest of this section.

@*1 The Each operator. The each operator (represented as $\ddot{ }$ 
in APL) is the operator that will be most familiar to you if you 
have read the preceding sections. It takes in any function and 
returns a scalar function that applies that given function to each 
of the scalars in turn just as a scalar function would. This 
implies that the functions given to the each operator should make 
sure to support scalar arrays. Our general implementation has 
a few responsibilities. We must make sure that there is enough 
space to store the result, and we must present the given 
function with something that looks like a scalar array. 
In the case where we receive empty arrays as the inputs, then we 
should give back an empty array. To handle all of this complexity, 
we divide the main task into the following sections:

@<APL Operators@>=
void eachm(AplArray *res, AplArray *rgt, AplFunction *env) 
{
	AplArray z, r; /* Scalar temporaries for the loop */
	AplArray tmp; /* Temporary array if necessary */
	AplArray *orig;
	AplType type;
	unsigned int siz; /* Elements to traverse */
	short rnk; /* Rank of |rgt| */
	short clean; /* Flag, indicates need to clean */
	@<Initialize variables for |eachm|@>@;
	@<Deal with the simple cases of |eachm|@>@;
	@<Determine the type of the result in |eachm|@>@;
	@<Allocate |res| in |eachm|@>@;
	@<Apply $\alpha\alpha$ monadically on each element@>@;
	@<Do any cleanup necessary in |each|@>@;
}

@ The dyadic version of each is much the same in outline. We need 
a few more variables to handle some of the complication that comes 
with dyadic functions, but the basic outline remains the same.

@<APL Operators@>=
void eachd(AplArray *res, AplArray *lft, AplArray *rgt, AplFunction *env)
{ 
	AplArray z, l, r; /* Scalar temporaries for the loop */
	AplArray tmp; /* Temporary for use during allocation */
	AplArray *shp, *orig;
	AplType type;
	unsigned int siz; /* Number of elements to iterate */
	short lftrnk, rgtrnk; /* Ranks of |lft| and |rgt| */
	short clean; /* Indicates cleanup is necessary */
	@<Initialize variables for |eachd|@>@;
	@<Deal with the simple cases of |eachd|@>@;
	@<Determine the type of the result in |eachd|@>@;
	@<Allocate |res| in |eachd|@>@;
	@<Apply $\alpha\alpha$ dyadically on each element@>@;
	@<Do any cleanup necessary in |each|@>@;
}

@ Let's do the initialization first. We want to initialize all the 
variables that we can ahead of time, but there are some variables, 
like |clean| and |size| that we cannot do until we know more 
about the relationship between all of the arguments. Otherwise, 
we need to make sure that all of our arrays are initialized and 
that we have the rank of the input array(s).

@<Initialize variables for |eachm|@>=
init_array(&z);
init_array(&r);
init_array(&tmp);
rnk = rank(rgt);

@ @<Initialize variables for |eachd|@>=
init_array(&z);
init_array(&l);
init_array(&r);
init_array(&tmp);
lftrnk = rank(lft);
rgtrnk = rank(rgt);

@ Both the monadic and dyadic forms of |each| have simple cases 
where we can avoid most of the other work. In both forms, if we are 
dealing with scalar inputs, then we can avoid most of the overhead 
entirely. If we are dealing with scalar vectors, we can achieve 
basically the same effect. If neither of these are the case, 
then we know a little something about the arrays, and we should 
save that for use later. 

@<Deal with the simple cases of |eachm|@>=
if (0 == rnk) {
	apply(env->lop.function, res, rgt);
	return;
} else siz = size(rgt);
if (0 == siz) {
	copy_array(res, rgt);
	return;
}

@ The dyadic case is a bit more complicated because we want to deal 
with scalar distribution as well as just the scalar inputs. This 
means that we will save a pointer to the array that guides the 
shape of the main function into the |shp| variable. This will be 
used later on to determine the shape of the result array. 

@<Deal with the simple cases of |eachd|@>=
if (0 == lftrnk) {
	if (0 == rgtrnk) {
		applyd(env->function, res, lft, rgt);
	} else {
		siz = size(rgt);
		shp = rgt;
	}
} else if (0 == rgtrnk) {
	siz = size(lft);
	shp = lft;
} else {
	siz = size(rgt);
	shp = rgt;
}
if (0 == siz) {
	copy_array(res, shp);
	return;
}

@ After we have determined that we are not dealing with a trivial 
case, and that we have at least one element to be considering, we 
must do some work to figure out what the resulting type of the 
computation will be. We do this by applying our function on the 
first element in the array, and then checking what that type is. 
We assume that the function will give us the same type for all 
of the other elements. 

@<Determine the type of the result in |eachm|@>=
r.type = rgt->type;
r.size = type_size(r.type);
r.data = rgt->data;
applym(env->lop.function, &z, &r);
type = z.type;

@ The dyadic case for determing the type of the return is the same 
as the monadic one, but we have one more scalar argument.

@<Determine the type of the result in |eachd|@>=
l.type = lft->type;
l.size = type_size(l.type);
l.data = lft->data;
r.type = rgt->type;
r.size = type_size(r.type);
r.data = rgt->data;
apply(env->lop.function, &z, &l, &r);
type = z.type;

@ After we know that we are dealing with the general case, and 
after we know the type of the result array, we are free to begin 
allocating the space for the result array. 
It is not as simple as just setting the shape and allocating an 
array, though. Here is where we must deal with the possibility 
that the input array is the same as the output array. This 
may require some temporary copying and the like. In the 
end, if we do need to create a temporary result array, then 
we will set |clean| to make sure that we know to clean it 
up at the end. At the end of this computation, the main 
invariant that we want to preserve is that |res| must point 
to an array that is safe to over-write element wise, and 
that is allocated and is the correct output shape. We do 
not guarantee after this that |res| is different than either 
of its inputs, in the case when it is possible to do an 
inplace update and that the type of the input array that 
might be the same as |res| is the same as the output type 
of the array |res|. Later on, we can check the |clean| 
variable to determine what case we are dealing with. If 
clean is set to |EACH_COPY|, then we know that we created 
a whole new copy to use, if it is |EACH_SAME| we know that 
one of the arrays is the same and that we should set the 
output type as part of our cleanup. Otherwise, when |clean| 
is |0|, there is no sharing and |res| is not temporarily 
allocated. 

@d EACH_COPY 1
@d EACH_SAME 2

@<Allocate |res| in |eachm|@>=
if (res == rgt) {
	if (type_size(type) > type_size(rgt)) {
		copy_shape(&tmp, rgt);
		alloc_array(&tmp, type);
		orig = res;
		res = &tmp;
		clean = EACH_COPY;
	} else {
		clean = EACH_SAME;
	}
} else {
	copy_shape(res, rgt);
	alloc_array(res, type);
	clean = 0;
}

@ The dyadic case is much the same as the monadic case, except 
that we do not know whether |lft| or |rgt| is the correct array 
on which to base the shape, so we instead rely on |shp| being set 
early on in the computation to the right array on which we can 
base our shape. The same guarantees and invariants mentioned in 
the previous section apply here.

@<Allocate |res| in |eachd|@>=
if (res == rgt || res == lft) {
	if ((res == shp || lftrnk == rgtrnk)
	    && type_size(type) <= type_size(res->type)) {
		clean = EACH_SAME;
	} else {
		copy_shape(&tmp, shp);
		alloc_array(&tmp, type);
		orig = res;
		res = &tmp;
		clean = EACH_COPY;
	}
} else {
	copy_shape(res, shp);
	alloc_array(res, type);
	clean = 0;
}

@ While we are still on the subject, let's make sure that we take 
care of the cleanup that we have done with these allocation 
functions. We do this now while the invariants are still fresh 
in our head. After this, all that is left to complete the 
implementation of |each|, both dyadically and monadically, is 
the main loop of the two functions |eachm| and |eachd|. 
We have three cases to deal with when we perform cleanup, 
two of which actually require any work. These cases are given by 
the |EACH_COPY| and the |EACH_SAME| constants. The no-op case is 
given when |clean == 0|. Otherwise, |clean| will be set to one of 
the aforementioned constants, and we need to do different clean 
up on each. 

\medskip
\item{|EACH_SAME|} In this case, we have not allocated a temporary 
array, instead reusing an input array. This also means that we 
did not set the |type| field of the result array so as to not 
mess with the integrity of the input array until after we had 
done all of the overwriting. We need to rectify this, but 
there are no other buffers or other things that need to be taken 
care of.
\item{|EACH_COPY|} Here, we have actually allocated temporary 
space for the resultant array so that we do not invalidate our 
input arrays with the output of the function. This means that 
we need to put the important data buffers into the correct output 
array, which we keep in the |orig| variable. 
\medskip

\noindent After we do this cleanup, the assumption is that we can 
safely return from the function.

@<Do any cleanup necessary in |each|@>=
switch (clean) {
case EACH_SAME: 
	res->type = type;
	break;
case EACH_COPY:
	free(orig->data);
	orig->size = tmp.size;
	orig->data = tmp.data;
	orig->type = tmp.type;
	copy_shape(orig, &tmp);
	break;
}

@ With all that preparation and setup complete, we are now ready to 
get down to the main event. This is the main loop that will actually 
do the iteration over the elements and apply the given function to 
each of them in turn. We try to do this efficiently by moving only 
over the data fields in each of the scalars. That is, we slide 
the data fields of the |z|, |l|, and |r| scalar temporaries along 
the larger data fields of the main inputs and outputs. 

@<Apply $\alpha\alpha$ monadically on each element@>=
z.size = type_size(type);
z.data = res->data;
z.type = res->type;
r.type = rgt->type;
r.size = type_size(rgt->type);
r.data = rgt->data;
for (i = 0; i < siz; i++) {
	apply(env->lop.function, &z, &r);
	z.data += z.size;
	r.data += r.size;
}

@ The dyadic case is virtually unchanged from this but for the 
extra argument.

@<Apply $\alpha\alpha$ dyadically on each element@>=
z.size = type_size(type); l.size = lft->size; r.size = rgt->size;
z.type = type; l.type = lft->type; r.type = rgt->type;
z.data = res->data; l.data = lft->data; r.data = rgt->data;
for (i = 0; i < siz; i++) {
	applyd(env->lop.function, &z, &l, &r); 
	z.data += z.size;
	l.data += l.size;
	r.data += r.size;
}


@* Reporting runtime errors. Much as I would like to think that my 
compiler and that my coding are perfect, it turns out that this is 
not going to happen. Imagine that. Instead, I want to have a good 
backup plan: error reports that make sense.  In general, this 
means that when I hit a major error, I report the error with a 
specific error code (macros starting with |APLERR_|) or report it 
as a warning (macros starting with |APLWARN_|), after I have 
reported the system error, if relevant. I leave it up to the 
call site whether or not to continue working or not.
What follows are the error message code that I use and their 
plain text descriptions in a static array.

@d APLERR_MALLOC 1
@d APLERR_SHAPEMISMATCH 2
@d APLERR_DOMAIN 3

@<Runtime error reporting@>=
char *error_messages[] = 
	{  @/
	  "Success", @/
	  "Allocation failure", /* |APLERR_MALLOC| */
	  "Shape mismatch", /* |APLERR_SHAPEMISMATCH| */
	  "Invalid domain" /* |APLERR_DOMAIN| */
	};
char *warning_messages[] =
	{  @/
	  "Success" @/
	};

@ The |apl_error| function is meant for reporting serious errors 
that are not part of the normal operation of the system.
The |apl_warning| function is for printing out non-critical 
warnings about things that are probably important, but that are 
not complete or partial show-stoppers. They should generally 
always be recoverable and should not halt the execution of the 
runtime.

@<Runtime error reporting@>=
void apl_error(int code)
{
	fprintf(stderr, "APL Error (%d): %s\n", code, 
	    error_messages[code]);
}
void apl_warning(int code)
{
	fprintf(stderr, "APL Warning (%d): %s\n",
	    code, warning_messages[code]);
}


@* Index.

