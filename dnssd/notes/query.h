/*********************************************************************************************
*
*  Querying Individual Specific Records
*
*********************************************************************************************/

/* DNSServiceQueryRecord
 *
 * Query for an arbitrary DNS record.
 *
 * DNSServiceQueryRecordReply() Callback Parameters:
 *
 * sdRef:           The DNSServiceRef initialized by DNSServiceQueryRecord().
 *
 * flags:           Possible values are kDNSServiceFlagsMoreComing and
 *                  kDNSServiceFlagsAdd. The Add flag is NOT set for PTR records
 *                  with a ttl of 0, i.e. "Remove" events.
 *
 * interfaceIndex:  The interface on which the query was resolved (the index for a given
 *                  interface is determined via the if_nametoindex() family of calls).
 *                  See "Constants for specifying an interface index" for more details.
 *
 * errorCode:       Will be kDNSServiceErr_NoError on success, otherwise will
 *                  indicate the failure that occurred. Other parameters are undefined if
 *                  errorCode is nonzero.
 *
 * fullname:        The resource record's full domain name.
 *
 * rrtype:          The resource record's type (e.g. kDNSServiceType_PTR, kDNSServiceType_SRV, etc)
 *
 * rrclass:         The class of the resource record (usually kDNSServiceClass_IN).
 *
 * rdlen:           The length, in bytes, of the resource record rdata.
 *
 * rdata:           The raw rdata of the resource record.
 *
 * ttl:             If the client wishes to cache the result for performance reasons,
 *                  the TTL indicates how long the client may legitimately hold onto
 *                  this result, in seconds. After the TTL expires, the client should
 *                  consider the result no longer valid, and if it requires this data
 *                  again, it should be re-fetched with a new query. Of course, this
 *                  only applies to clients that cancel the asynchronous operation when
 *                  they get a result. Clients that leave the asynchronous operation
 *                  running can safely assume that the data remains valid until they
 *                  get another callback telling them otherwise. The ttl value is not
 *                  updated when the daemon answers from the cache, hence relying on
 *                  the accuracy of the ttl value is not recommended.
 *
 * context:         The context pointer that was passed to the callout.
 *
 */

typedef void (DNSSD_API *DNSServiceQueryRecordReply)
(
    DNSServiceRef sdRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    DNSServiceErrorType errorCode,
    const char                          *fullname,
    uint16_t rrtype,
    uint16_t rrclass,
    uint16_t rdlen,
    const void                          *rdata,
    uint32_t ttl,
    void                                *context
);


/* DNSServiceQueryRecord() Parameters:
 *
 * sdRef:           A pointer to an uninitialized DNSServiceRef. If the call succeeds
 *                  then it initializes the DNSServiceRef, returns kDNSServiceErr_NoError,
 *                  and the query operation will run indefinitely until the client
 *                  terminates it by passing this DNSServiceRef to DNSServiceRefDeallocate().
 *
 * flags:           kDNSServiceFlagsForceMulticast or kDNSServiceFlagsLongLivedQuery.
 *                  Pass kDNSServiceFlagsLongLivedQuery to create a "long-lived" unicast
 *                  query to a unicast DNS server that implements the protocol. This flag
 *                  has no effect on link-local multicast queries.
 *
 * interfaceIndex:  If non-zero, specifies the interface on which to issue the query
 *                  (the index for a given interface is determined via the if_nametoindex()
 *                  family of calls.) Passing 0 causes the name to be queried for on all
 *                  interfaces. See "Constants for specifying an interface index" for more details.
 *
 * fullname:        The full domain name of the resource record to be queried for.
 *
 * rrtype:          The numerical type of the resource record to be queried for
 *                  (e.g. kDNSServiceType_PTR, kDNSServiceType_SRV, etc)
 *
 * rrclass:         The class of the resource record (usually kDNSServiceClass_IN).
 *
 * callBack:        The function to be called when a result is found, or if the call
 *                  asynchronously fails.
 *
 * context:         An application context pointer which is passed to the callback function
 *                  (may be NULL).
 *
 * return value:    Returns kDNSServiceErr_NoError on success (any subsequent, asynchronous
 *                  errors are delivered to the callback), otherwise returns an error code indicating
 *                  the error that occurred (the callback is never invoked and the DNSServiceRef
 *                  is not initialized).
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API DNSServiceQueryRecord
(
    DNSServiceRef                       *sdRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    const char                          *fullname,
    uint16_t rrtype,
    uint16_t rrclass,
    DNSServiceQueryRecordReply callBack,
    void                                *context  /* may be NULL */
);
