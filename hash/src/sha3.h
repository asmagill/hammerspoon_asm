// Modified from code at https://github.com/rhash/RHash

#pragma once

@import Cocoa ;

#define sha3_224_hash_size  28
#define sha3_256_hash_size  32
#define sha3_384_hash_size  48
#define sha3_512_hash_size  64
#define sha3_max_permutation_size 25
#define sha3_max_rate_in_qwords 24

/**
 * SHA3 Algorithm context.
 */
typedef struct sha3_ctx
{
    /* 1600 bits algorithm hashing state */
    uint64_t hash[sha3_max_permutation_size];
    /* 1536-bit buffer for leftovers */
    uint64_t message[sha3_max_rate_in_qwords];
    /* count of bytes in the message[] buffer */
    unsigned rest;
    /* size of a message block processed at once */
    unsigned block_size;
} sha3_ctx;

/* methods for calculating the hash function */

void rhash_sha3_224_init(sha3_ctx* ctx);
void rhash_sha3_256_init(sha3_ctx* ctx);
void rhash_sha3_384_init(sha3_ctx* ctx);
void rhash_sha3_512_init(sha3_ctx* ctx);
void rhash_sha3_update(sha3_ctx* ctx, const unsigned char* msg, size_t size);
void rhash_sha3_final(sha3_ctx* ctx, unsigned char* result);

extern void *init_SHA3_224(NSData *key) ;
extern void append_SHA3_224(void *_context, NSData *data) ;
extern NSData *finish_SHA3_224(void *_context) ;

extern void *init_SHA3_256(NSData *key) ;
extern void append_SHA3_256(void *_context, NSData *data) ;
extern NSData *finish_SHA3_256(void *_context) ;

extern void *init_SHA3_384(NSData *key) ;
extern void append_SHA3_384(void *_context, NSData *data) ;
extern NSData *finish_SHA3_384(void *_context) ;

extern void *init_SHA3_512(NSData *key) ;
extern void append_SHA3_512(void *_context, NSData *data) ;
extern NSData *finish_SHA3_512(void *_context) ;
