/*
REQUIRED_ARGS: -extern-std=c++98 -HC -c -o-
PERMUTE_ARGS:
TEST_OUTPUT:
---
// Automatically generated by Digital Mars D Compiler

#pragma once

#include <assert.h>
#include <stddef.h>
#include <stdint.h>
#include <math.h>

#ifdef CUSTOM_D_ARRAY_TYPE
#define _d_dynamicArray CUSTOM_D_ARRAY_TYPE
#else
/// Represents a D [] array
template<typename T>
struct _d_dynamicArray
{
    size_t length;
    T *ptr;

    _d_dynamicArray() : length(0), ptr(NULL) { }

    _d_dynamicArray(size_t length_in, T *ptr_in)
        : length(length_in), ptr(ptr_in) { }

    T& operator[](const size_t idx) {
        assert(idx < length);
        return ptr[idx];
    }

    const T& operator[](const size_t idx) const {
        assert(idx < length);
        return ptr[idx];
    }
};
#endif

struct Null
{
    void* field;
private:
    Null(int32_t );
public:
    Null() :
        field(NULL)
    {
    }
};

extern void* typeof_null;

extern void* inferred_null;

---
*/

extern (C++) struct Null
{
    void* field = null;

    @disable this(int);
}

extern (C++) __gshared typeof(null) typeof_null = null;
extern (C++) __gshared inferred_null = null;
