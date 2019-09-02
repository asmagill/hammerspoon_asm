#ifndef __OPEN_SOURCE__

/* PeerConnectionRelease() Parameters
 *
 * Release P2P connection resources associated with the service instance.
 * When a service is resolved over a P2P interface, a connection is brought up to the
 * peer advertising the service instance.  This call will free the resources associated
 * with that connection.  Note that the reference to the service instance will only
 * be maintained by the daemon while the browse for the service type is still
 * running.  Thus the sequence of calls to discover, resolve, and then terminate the connection
 * associated with a given P2P service instance would be:
 *
 *   DNSServiceRef BrowseRef, ResolveRef;
 *      DNSServiceBrowse(&BrowseRef, ...)    // browse for all instances of the service
 *      DNSServiceResolve(&ResolveRef, ...)  // resolving a service instance creates a
 *                                           // connection to the peer device advertising that service
 *      DNSServiceRefDeallocate(ResolveRef)  // Stop the resolve, which does not close the peer connection
 *
 *          // Communicate with the peer application.
 *
 *      PeerConnectionRelease()  // release the connection to the peer device for the specified service instance
 *
 *      DNSServiceRefDeallocate(BrowseRef)  // stop the browse
 *          // Any further calls to PeerConnectionRelease() will have no affect since the
 *          // service instance to peer connection relationship is only maintained by the
 *          // daemon while the browse is running.
 *
 *
 * flags:           Not currently used.
 *
 * name:            The name of the service instance to be resolved, as reported to the
 *                  DNSServiceBrowseReply() callback.
 *
 * regtype:         The type of the service instance to be resolved, as reported to the
 *                  DNSServiceBrowseReply() callback.
 *
 * domain:          The domain of the service instance to be resolved, as reported to the
 *                  DNSServiceBrowseReply() callback.
 *
 * return value:    Returns kDNSServiceErr_NoError on success or the error that occurred.
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API PeerConnectionRelease
(
    DNSServiceFlags flags,
    const char      *name,
    const char      *regtype,
    const char      *domain
);

#endif // __OPEN_SOURCE__

/*********************************************************************************************
*
*  General Utility Functions
*
*********************************************************************************************/

/* DNSServiceConstructFullName()
 *
 * Concatenate a three-part domain name (as returned by the above callbacks) into a
 * properly-escaped full domain name. Note that callbacks in the above functions ALREADY ESCAPE
 * strings where necessary.
 *
 * Parameters:
 *
 * fullName:        A pointer to a buffer that where the resulting full domain name is to be written.
 *                  The buffer must be kDNSServiceMaxDomainName (1009) bytes in length to
 *                  accommodate the longest legal domain name without buffer overrun.
 *
 * service:         The service name - any dots or backslashes must NOT be escaped.
 *                  May be NULL (to construct a PTR record name, e.g.
 *                  "_ftp._tcp.apple.com.").
 *
 * regtype:         The service type followed by the protocol, separated by a dot
 *                  (e.g. "_ftp._tcp").
 *
 * domain:          The domain name, e.g. "apple.com.". Literal dots or backslashes,
 *                  if any, must be escaped, e.g. "1st\. Floor.apple.com."
 *
 * return value:    Returns kDNSServiceErr_NoError (0) on success, kDNSServiceErr_BadParam on error.
 *
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API DNSServiceConstructFullName
(
    char                            * const fullName,
    const char                      * const service,      /* may be NULL */
    const char                      * const regtype,
    const char                      * const domain
);


/*********************************************************************************************
*
*   TXT Record Construction Functions
*
*********************************************************************************************/

/*
 * A typical calling sequence for TXT record construction is something like:
 *
 * Client allocates storage for TXTRecord data (e.g. declare buffer on the stack)
 * TXTRecordCreate();
 * TXTRecordSetValue();
 * TXTRecordSetValue();
 * TXTRecordSetValue();
 * ...
 * DNSServiceRegister( ... TXTRecordGetLength(), TXTRecordGetBytesPtr() ... );
 * TXTRecordDeallocate();
 * Explicitly deallocate storage for TXTRecord data (if not allocated on the stack)
 */


/* TXTRecordRef
 *
 * Opaque internal data type.
 * Note: Represents a DNS-SD TXT record.
 */

typedef union _TXTRecordRef_t { char PrivateData[16]; char *ForceNaturalAlignment; } TXTRecordRef;


/* TXTRecordCreate()
 *
 * Creates a new empty TXTRecordRef referencing the specified storage.
 *
 * If the buffer parameter is NULL, or the specified storage size is not
 * large enough to hold a key subsequently added using TXTRecordSetValue(),
 * then additional memory will be added as needed using malloc().
 *
 * On some platforms, when memory is low, malloc() may fail. In this
 * case, TXTRecordSetValue() will return kDNSServiceErr_NoMemory, and this
 * error condition will need to be handled as appropriate by the caller.
 *
 * You can avoid the need to handle this error condition if you ensure
 * that the storage you initially provide is large enough to hold all
 * the key/value pairs that are to be added to the record.
 * The caller can precompute the exact length required for all of the
 * key/value pairs to be added, or simply provide a fixed-sized buffer
 * known in advance to be large enough.
 * A no-value (key-only) key requires  (1 + key length) bytes.
 * A key with empty value requires     (1 + key length + 1) bytes.
 * A key with non-empty value requires (1 + key length + 1 + value length).
 * For most applications, DNS-SD TXT records are generally
 * less than 100 bytes, so in most cases a simple fixed-sized
 * 256-byte buffer will be more than sufficient.
 * Recommended size limits for DNS-SD TXT Records are discussed in RFC 6763
 * <https://tools.ietf.org/html/rfc6763#section-6.2>
 *
 * Note: When passing parameters to and from these TXT record APIs,
 * the key name does not include the '=' character. The '=' character
 * is the separator between the key and value in the on-the-wire
 * packet format; it is not part of either the key or the value.
 *
 * txtRecord:       A pointer to an uninitialized TXTRecordRef.
 *
 * bufferLen:       The size of the storage provided in the "buffer" parameter.
 *
 * buffer:          Optional caller-supplied storage used to hold the TXTRecord data.
 *                  This storage must remain valid for as long as
 *                  the TXTRecordRef.
 */

DNSSD_EXPORT
void DNSSD_API TXTRecordCreate
(
    TXTRecordRef     *txtRecord,
    uint16_t bufferLen,
    void             *buffer
);


/* TXTRecordDeallocate()
 *
 * Releases any resources allocated in the course of preparing a TXT Record
 * using TXTRecordCreate()/TXTRecordSetValue()/TXTRecordRemoveValue().
 * Ownership of the buffer provided in TXTRecordCreate() returns to the client.
 *
 * txtRecord:           A TXTRecordRef initialized by calling TXTRecordCreate().
 *
 */

DNSSD_EXPORT
void DNSSD_API TXTRecordDeallocate
(
    TXTRecordRef     *txtRecord
);


/* TXTRecordSetValue()
 *
 * Adds a key (optionally with value) to a TXTRecordRef. If the "key" already
 * exists in the TXTRecordRef, then the current value will be replaced with
 * the new value.
 * Keys may exist in four states with respect to a given TXT record:
 *  - Absent (key does not appear at all)
 *  - Present with no value ("key" appears alone)
 *  - Present with empty value ("key=" appears in TXT record)
 *  - Present with non-empty value ("key=value" appears in TXT record)
 * For more details refer to "Data Syntax for DNS-SD TXT Records" in RFC 6763
 * <https://tools.ietf.org/html/rfc6763#section-6>
 *
 * txtRecord:       A TXTRecordRef initialized by calling TXTRecordCreate().
 *
 * key:             A null-terminated string which only contains printable ASCII
 *                  values (0x20-0x7E), excluding '=' (0x3D). Keys should be
 *                  9 characters or fewer (not counting the terminating null).
 *
 * valueSize:       The size of the value.
 *
 * value:           Any binary value. For values that represent
 *                  textual data, UTF-8 is STRONGLY recommended.
 *                  For values that represent textual data, valueSize
 *                  should NOT include the terminating null (if any)
 *                  at the end of the string.
 *                  If NULL, then "key" will be added with no value.
 *                  If non-NULL but valueSize is zero, then "key=" will be
 *                  added with empty value.
 *
 * return value:    Returns kDNSServiceErr_NoError on success.
 *                  Returns kDNSServiceErr_Invalid if the "key" string contains
 *                  illegal characters.
 *                  Returns kDNSServiceErr_NoMemory if adding this key would
 *                  exceed the available storage.
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API TXTRecordSetValue
(
    TXTRecordRef     *txtRecord,
    const char       *key,
    uint8_t valueSize,                 /* may be zero */
    const void       *value            /* may be NULL */
);


/* TXTRecordRemoveValue()
 *
 * Removes a key from a TXTRecordRef. The "key" must be an
 * ASCII string which exists in the TXTRecordRef.
 *
 * txtRecord:       A TXTRecordRef initialized by calling TXTRecordCreate().
 *
 * key:             A key name which exists in the TXTRecordRef.
 *
 * return value:    Returns kDNSServiceErr_NoError on success.
 *                  Returns kDNSServiceErr_NoSuchKey if the "key" does not
 *                  exist in the TXTRecordRef.
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API TXTRecordRemoveValue
(
    TXTRecordRef     *txtRecord,
    const char       *key
);


/* TXTRecordGetLength()
 *
 * Allows you to determine the length of the raw bytes within a TXTRecordRef.
 *
 * txtRecord:       A TXTRecordRef initialized by calling TXTRecordCreate().
 *
 * return value:    Returns the size of the raw bytes inside a TXTRecordRef
 *                  which you can pass directly to DNSServiceRegister() or
 *                  to DNSServiceUpdateRecord().
 *                  Returns 0 if the TXTRecordRef is empty.
 */

DNSSD_EXPORT
uint16_t DNSSD_API TXTRecordGetLength
(
    const TXTRecordRef *txtRecord
);


/* TXTRecordGetBytesPtr()
 *
 * Allows you to retrieve a pointer to the raw bytes within a TXTRecordRef.
 *
 * txtRecord:       A TXTRecordRef initialized by calling TXTRecordCreate().
 *
 * return value:    Returns a pointer to the raw bytes inside the TXTRecordRef
 *                  which you can pass directly to DNSServiceRegister() or
 *                  to DNSServiceUpdateRecord().
 */

DNSSD_EXPORT
const void * DNSSD_API TXTRecordGetBytesPtr
(
    const TXTRecordRef *txtRecord
);


/*********************************************************************************************
*
*   TXT Record Parsing Functions
*
*********************************************************************************************/

/*
 * A typical calling sequence for TXT record parsing is something like:
 *
 * Receive TXT record data in DNSServiceResolve() callback
 * if (TXTRecordContainsKey(txtLen, txtRecord, "key")) then do something
 * val1ptr = TXTRecordGetValuePtr(txtLen, txtRecord, "key1", &len1);
 * val2ptr = TXTRecordGetValuePtr(txtLen, txtRecord, "key2", &len2);
 * ...
 * memcpy(myval1, val1ptr, len1);
 * memcpy(myval2, val2ptr, len2);
 * ...
 * return;
 *
 * If you wish to retain the values after return from the DNSServiceResolve()
 * callback, then you need to copy the data to your own storage using memcpy()
 * or similar, as shown in the example above.
 *
 * If for some reason you need to parse a TXT record you built yourself
 * using the TXT record construction functions above, then you can do
 * that using TXTRecordGetLength and TXTRecordGetBytesPtr calls:
 * TXTRecordGetValue(TXTRecordGetLength(x), TXTRecordGetBytesPtr(x), key, &len);
 *
 * Most applications only fetch keys they know about from a TXT record and
 * ignore the rest.
 * However, some debugging tools wish to fetch and display all keys.
 * To do that, use the TXTRecordGetCount() and TXTRecordGetItemAtIndex() calls.
 */

/* TXTRecordContainsKey()
 *
 * Allows you to determine if a given TXT Record contains a specified key.
 *
 * txtLen:          The size of the received TXT Record.
 *
 * txtRecord:       Pointer to the received TXT Record bytes.
 *
 * key:             A null-terminated ASCII string containing the key name.
 *
 * return value:    Returns 1 if the TXT Record contains the specified key.
 *                  Otherwise, it returns 0.
 */

DNSSD_EXPORT
int DNSSD_API TXTRecordContainsKey
(
    uint16_t txtLen,
    const void       *txtRecord,
    const char       *key
);


/* TXTRecordGetValuePtr()
 *
 * Allows you to retrieve the value for a given key from a TXT Record.
 *
 * txtLen:          The size of the received TXT Record
 *
 * txtRecord:       Pointer to the received TXT Record bytes.
 *
 * key:             A null-terminated ASCII string containing the key name.
 *
 * valueLen:        On output, will be set to the size of the "value" data.
 *
 * return value:    Returns NULL if the key does not exist in this TXT record,
 *                  or exists with no value (to differentiate between
 *                  these two cases use TXTRecordContainsKey()).
 *                  Returns pointer to location within TXT Record bytes
 *                  if the key exists with empty or non-empty value.
 *                  For empty value, valueLen will be zero.
 *                  For non-empty value, valueLen will be length of value data.
 */

DNSSD_EXPORT
const void * DNSSD_API TXTRecordGetValuePtr
(
    uint16_t txtLen,
    const void       *txtRecord,
    const char       *key,
    uint8_t          *valueLen
);


/* TXTRecordGetCount()
 *
 * Returns the number of keys stored in the TXT Record. The count
 * can be used with TXTRecordGetItemAtIndex() to iterate through the keys.
 *
 * txtLen:          The size of the received TXT Record.
 *
 * txtRecord:       Pointer to the received TXT Record bytes.
 *
 * return value:    Returns the total number of keys in the TXT Record.
 *
 */

DNSSD_EXPORT
uint16_t DNSSD_API TXTRecordGetCount
(
    uint16_t txtLen,
    const void       *txtRecord
);


/* TXTRecordGetItemAtIndex()
 *
 * Allows you to retrieve a key name and value pointer, given an index into
 * a TXT Record. Legal index values range from zero to TXTRecordGetCount()-1.
 * It's also possible to iterate through keys in a TXT record by simply
 * calling TXTRecordGetItemAtIndex() repeatedly, beginning with index zero
 * and increasing until TXTRecordGetItemAtIndex() returns kDNSServiceErr_Invalid.
 *
 * On return:
 * For keys with no value, *value is set to NULL and *valueLen is zero.
 * For keys with empty value, *value is non-NULL and *valueLen is zero.
 * For keys with non-empty value, *value is non-NULL and *valueLen is non-zero.
 *
 * txtLen:          The size of the received TXT Record.
 *
 * txtRecord:       Pointer to the received TXT Record bytes.
 *
 * itemIndex:       An index into the TXT Record.
 *
 * keyBufLen:       The size of the string buffer being supplied.
 *
 * key:             A string buffer used to store the key name.
 *                  On return, the buffer contains a null-terminated C string
 *                  giving the key name. DNS-SD TXT keys are usually
 *                  9 characters or fewer. To hold the maximum possible
 *                  key name, the buffer should be 256 bytes long.
 *
 * valueLen:        On output, will be set to the size of the "value" data.
 *
 * value:           On output, *value is set to point to location within TXT
 *                  Record bytes that holds the value data.
 *
 * return value:    Returns kDNSServiceErr_NoError on success.
 *                  Returns kDNSServiceErr_NoMemory if keyBufLen is too short.
 *                  Returns kDNSServiceErr_Invalid if index is greater than
 *                  TXTRecordGetCount()-1.
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API TXTRecordGetItemAtIndex
(
    uint16_t txtLen,
    const void       *txtRecord,
    uint16_t itemIndex,
    uint16_t keyBufLen,
    char             *key,
    uint8_t          *valueLen,
    const void       **value
);
