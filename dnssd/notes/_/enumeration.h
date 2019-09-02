/*********************************************************************************************
*
* Domain Enumeration
*
*********************************************************************************************/

/* DNSServiceEnumerateDomains()
 *
 * Asynchronously enumerate domains available for browsing and registration.
 *
 * The enumeration MUST be cancelled via DNSServiceRefDeallocate() when no more domains
 * are to be found.
 *
 * Note that the names returned are (like all of DNS-SD) UTF-8 strings,
 * and are escaped using standard DNS escaping rules.
 * (See "Notes on DNS Name Escaping" earlier in this file for more details.)
 * A graphical browser displaying a hierarchical tree-structured view should cut
 * the names at the bare dots to yield individual labels, then de-escape each
 * label according to the escaping rules, and then display the resulting UTF-8 text.
 *
 * DNSServiceDomainEnumReply Callback Parameters:
 *
 * sdRef:           The DNSServiceRef initialized by DNSServiceEnumerateDomains().
 *
 * flags:           Possible values are:
 *                  kDNSServiceFlagsMoreComing
 *                  kDNSServiceFlagsAdd
 *                  kDNSServiceFlagsDefault
 *
 * interfaceIndex:  Specifies the interface on which the domain exists. (The index for a given
 *                  interface is determined via the if_nametoindex() family of calls.)
 *
 * errorCode:       Will be kDNSServiceErr_NoError (0) on success, otherwise indicates
 *                  the failure that occurred (other parameters are undefined if errorCode is nonzero).
 *
 * replyDomain:     The name of the domain.
 *
 * context:         The context pointer passed to DNSServiceEnumerateDomains.
 *
 */

typedef void (DNSSD_API *DNSServiceDomainEnumReply)
(
    DNSServiceRef sdRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    DNSServiceErrorType errorCode,
    const char                          *replyDomain,
    void                                *context
);


/* DNSServiceEnumerateDomains() Parameters:
 *
 * sdRef:           A pointer to an uninitialized DNSServiceRef. If the call succeeds
 *                  then it initializes the DNSServiceRef, returns kDNSServiceErr_NoError,
 *                  and the enumeration operation will run indefinitely until the client
 *                  terminates it by passing this DNSServiceRef to DNSServiceRefDeallocate().
 *
 * flags:           Possible values are:
 *                  kDNSServiceFlagsBrowseDomains to enumerate domains recommended for browsing.
 *                  kDNSServiceFlagsRegistrationDomains to enumerate domains recommended
 *                  for registration.
 *
 * interfaceIndex:  If non-zero, specifies the interface on which to look for domains.
 *                  (the index for a given interface is determined via the if_nametoindex()
 *                  family of calls.) Most applications will pass 0 to enumerate domains on
 *                  all interfaces. See "Constants for specifying an interface index" for more details.
 *
 * callBack:        The function to be called when a domain is found or the call asynchronously
 *                  fails.
 *
 * context:         An application context pointer which is passed to the callback function
 *                  (may be NULL).
 *
 * return value:    Returns kDNSServiceErr_NoError on success (any subsequent, asynchronous
 *                  errors are delivered to the callback), otherwise returns an error code indicating
 *                  the error that occurred (the callback is not invoked and the DNSServiceRef
 *                  is not initialized).
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API DNSServiceEnumerateDomains
(
    DNSServiceRef                       *sdRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    DNSServiceDomainEnumReply callBack,
    void                                *context  /* may be NULL */
);
