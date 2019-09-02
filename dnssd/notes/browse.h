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

/*********************************************************************************************
*
*  Service Discovery
*
*********************************************************************************************/

/* Browse for instances of a service.
 *
 * DNSServiceBrowseReply() Parameters:
 *
 * sdRef:           The DNSServiceRef initialized by DNSServiceBrowse().
 *
 * flags:           Possible values are kDNSServiceFlagsMoreComing and kDNSServiceFlagsAdd.
 *                  See flag definitions for details.
 *
 * interfaceIndex:  The interface on which the service is advertised. This index should
 *                  be passed to DNSServiceResolve() when resolving the service.
 *
 * errorCode:       Will be kDNSServiceErr_NoError (0) on success, otherwise will
 *                  indicate the failure that occurred. Other parameters are undefined if
 *                  the errorCode is nonzero.
 *
 * serviceName:     The discovered service name. This name should be displayed to the user,
 *                  and stored for subsequent use in the DNSServiceResolve() call.
 *
 * regtype:         The service type, which is usually (but not always) the same as was passed
 *                  to DNSServiceBrowse(). One case where the discovered service type may
 *                  not be the same as the requested service type is when using subtypes:
 *                  The client may want to browse for only those ftp servers that allow
 *                  anonymous connections. The client will pass the string "_ftp._tcp,_anon"
 *                  to DNSServiceBrowse(), but the type of the service that's discovered
 *                  is simply "_ftp._tcp". The regtype for each discovered service instance
 *                  should be stored along with the name, so that it can be passed to
 *                  DNSServiceResolve() when the service is later resolved.
 *
 * domain:          The domain of the discovered service instance. This may or may not be the
 *                  same as the domain that was passed to DNSServiceBrowse(). The domain for each
 *                  discovered service instance should be stored along with the name, so that
 *                  it can be passed to DNSServiceResolve() when the service is later resolved.
 *
 * context:         The context pointer that was passed to the callout.
 *
 */

typedef void (DNSSD_API *DNSServiceBrowseReply)
(
    DNSServiceRef sdRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    DNSServiceErrorType errorCode,
    const char                          *serviceName,
    const char                          *regtype,
    const char                          *replyDomain,
    void                                *context
);


/* DNSServiceBrowse() Parameters:
 *
 * sdRef:           A pointer to an uninitialized DNSServiceRef. If the call succeeds
 *                  then it initializes the DNSServiceRef, returns kDNSServiceErr_NoError,
 *                  and the browse operation will run indefinitely until the client
 *                  terminates it by passing this DNSServiceRef to DNSServiceRefDeallocate().
 *
 * flags:           Currently ignored, reserved for future use.
 *
 * interfaceIndex:  If non-zero, specifies the interface on which to browse for services
 *                  (the index for a given interface is determined via the if_nametoindex()
 *                  family of calls.) Most applications will pass 0 to browse on all available
 *                  interfaces. See "Constants for specifying an interface index" for more details.
 *
 * regtype:         The service type being browsed for followed by the protocol, separated by a
 *                  dot (e.g. "_ftp._tcp"). The transport protocol must be "_tcp" or "_udp".
 *                  A client may optionally specify a single subtype to perform filtered browsing:
 *                  e.g. browsing for "_primarytype._tcp,_subtype" will discover only those
 *                  instances of "_primarytype._tcp" that were registered specifying "_subtype"
 *                  in their list of registered subtypes. Additionally, a group identifier may
 *                  also be specified before the subtype e.g., _primarytype._tcp:GroupID, which
 *                  will discover only the members that register the service with GroupID. See
 *                  DNSServiceRegister for more details.
 *
 * domain:          If non-NULL, specifies the domain on which to browse for services.
 *                  Most applications will not specify a domain, instead browsing on the
 *                  default domain(s).
 *
 * callBack:        The function to be called when an instance of the service being browsed for
 *                  is found, or if the call asynchronously fails.
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
DNSServiceErrorType DNSSD_API DNSServiceBrowse
(
    DNSServiceRef                       *sdRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    const char                          *regtype,
    const char                          *domain,    /* may be NULL */
    DNSServiceBrowseReply callBack,
    void                                *context    /* may be NULL */
);


/* DNSServiceResolve()
 *
 * Resolve a service name discovered via DNSServiceBrowse() to a target host name, port number, and
 * txt record.
 *
 * Note: Applications should NOT use DNSServiceResolve() solely for txt record monitoring - use
 * DNSServiceQueryRecord() instead, as it is more efficient for this task.
 *
 * Note: When the desired results have been returned, the client MUST terminate the resolve by calling
 * DNSServiceRefDeallocate().
 *
 * Note: DNSServiceResolve() behaves correctly for typical services that have a single SRV record
 * and a single TXT record. To resolve non-standard services with multiple SRV or TXT records,
 * DNSServiceQueryRecord() should be used.
 *
 * DNSServiceResolveReply Callback Parameters:
 *
 * sdRef:           The DNSServiceRef initialized by DNSServiceResolve().
 *
 * flags:           Possible values: kDNSServiceFlagsMoreComing
 *
 * interfaceIndex:  The interface on which the service was resolved.
 *
 * errorCode:       Will be kDNSServiceErr_NoError (0) on success, otherwise will
 *                  indicate the failure that occurred. Other parameters are undefined if
 *                  the errorCode is nonzero.
 *
 * fullname:        The full service domain name, in the form <servicename>.<protocol>.<domain>.
 *                  (This name is escaped following standard DNS rules, making it suitable for
 *                  passing to standard system DNS APIs such as res_query(), or to the
 *                  special-purpose functions included in this API that take fullname parameters.
 *                  See "Notes on DNS Name Escaping" earlier in this file for more details.)
 *
 * hosttarget:      The target hostname of the machine providing the service. This name can
 *                  be passed to functions like gethostbyname() to identify the host's IP address.
 *
 * port:            The port, in network byte order, on which connections are accepted for this service.
 *
 * txtLen:          The length of the txt record, in bytes.
 *
 * txtRecord:       The service's primary txt record, in standard txt record format.
 *
 * context:         The context pointer that was passed to the callout.
 *
 * NOTE: In earlier versions of this header file, the txtRecord parameter was declared "const char *"
 * This is incorrect, since it contains length bytes which are values in the range 0 to 255, not -128 to +127.
 * Depending on your compiler settings, this change may cause signed/unsigned mismatch warnings.
 * These should be fixed by updating your own callback function definition to match the corrected
 * function signature using "const unsigned char *txtRecord". Making this change may also fix inadvertent
 * bugs in your callback function, where it could have incorrectly interpreted a length byte with value 250
 * as being -6 instead, with various bad consequences ranging from incorrect operation to software crashes.
 * If you need to maintain portable code that will compile cleanly with both the old and new versions of
 * this header file, you should update your callback function definition to use the correct unsigned value,
 * and then in the place where you pass your callback function to DNSServiceResolve(), use a cast to eliminate
 * the compiler warning, e.g.:
 *   DNSServiceResolve(sd, flags, index, name, regtype, domain, (DNSServiceResolveReply)MyCallback, context);
 * This will ensure that your code compiles cleanly without warnings (and more importantly, works correctly)
 * with both the old header and with the new corrected version.
 *
 */

typedef void (DNSSD_API *DNSServiceResolveReply)
(
    DNSServiceRef sdRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    DNSServiceErrorType errorCode,
    const char                          *fullname,
    const char                          *hosttarget,
    uint16_t port,                                   /* In network byte order */
    uint16_t txtLen,
    const unsigned char                 *txtRecord,
    void                                *context
);


/* DNSServiceResolve() Parameters
 *
 * sdRef:           A pointer to an uninitialized DNSServiceRef. If the call succeeds
 *                  then it initializes the DNSServiceRef, returns kDNSServiceErr_NoError,
 *                  and the resolve operation will run indefinitely until the client
 *                  terminates it by passing this DNSServiceRef to DNSServiceRefDeallocate().
 *
 * flags:           Specifying kDNSServiceFlagsForceMulticast will cause query to be
 *                  performed with a link-local mDNS query, even if the name is an
 *                  apparently non-local name (i.e. a name not ending in ".local.")
 *
 * interfaceIndex:  The interface on which to resolve the service. If this resolve call is
 *                  as a result of a currently active DNSServiceBrowse() operation, then the
 *                  interfaceIndex should be the index reported in the DNSServiceBrowseReply
 *                  callback. If this resolve call is using information previously saved
 *                  (e.g. in a preference file) for later use, then use interfaceIndex 0, because
 *                  the desired service may now be reachable via a different physical interface.
 *                  See "Constants for specifying an interface index" for more details.
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
DNSServiceErrorType DNSSD_API DNSServiceResolve
(
    DNSServiceRef                       *sdRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    const char                          *name,
    const char                          *regtype,
    const char                          *domain,
    DNSServiceResolveReply callBack,
    void                                *context  /* may be NULL */
);
