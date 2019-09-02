/*********************************************************************************************
*
*  Service Registration
*
*********************************************************************************************/

/* Register a service that is discovered via Browse() and Resolve() calls.
 *
 * DNSServiceRegisterReply() Callback Parameters:
 *
 * sdRef:           The DNSServiceRef initialized by DNSServiceRegister().
 *
 * flags:           When a name is successfully registered, the callback will be
 *                  invoked with the kDNSServiceFlagsAdd flag set. When Wide-Area
 *                  DNS-SD is in use, it is possible for a single service to get
 *                  more than one success callback (e.g. one in the "local" multicast
 *                  DNS domain, and another in a wide-area unicast DNS domain).
 *                  If a successfully-registered name later suffers a name conflict
 *                  or similar problem and has to be deregistered, the callback will
 *                  be invoked with the kDNSServiceFlagsAdd flag not set. The callback
 *                  is *not* invoked in the case where the caller explicitly terminates
 *                  the service registration by calling DNSServiceRefDeallocate(ref);
 *
 * errorCode:       Will be kDNSServiceErr_NoError on success, otherwise will
 *                  indicate the failure that occurred (including name conflicts,
 *                  if the kDNSServiceFlagsNoAutoRename flag was used when registering.)
 *                  Other parameters are undefined if errorCode is nonzero.
 *
 * name:            The service name registered (if the application did not specify a name in
 *                  DNSServiceRegister(), this indicates what name was automatically chosen).
 *
 * regtype:         The type of service registered, as it was passed to the callout.
 *
 * domain:          The domain on which the service was registered (if the application did not
 *                  specify a domain in DNSServiceRegister(), this indicates the default domain
 *                  on which the service was registered).
 *
 * context:         The context pointer that was passed to the callout.
 *
 */

typedef void (DNSSD_API *DNSServiceRegisterReply)
(
    DNSServiceRef sdRef,
    DNSServiceFlags flags,
    DNSServiceErrorType errorCode,
    const char                          *name,
    const char                          *regtype,
    const char                          *domain,
    void                                *context
);


/* DNSServiceRegister() Parameters:
 *
 * sdRef:           A pointer to an uninitialized DNSServiceRef. If the call succeeds
 *                  then it initializes the DNSServiceRef, returns kDNSServiceErr_NoError,
 *                  and the registration will remain active indefinitely until the client
 *                  terminates it by passing this DNSServiceRef to DNSServiceRefDeallocate().
 *
 * flags:           Indicates the renaming behavior on name conflict (most applications
 *                  will pass 0). See flag definitions above for details.
 *
 * interfaceIndex:  If non-zero, specifies the interface on which to register the service
 *                  (the index for a given interface is determined via the if_nametoindex()
 *                  family of calls.) Most applications will pass 0 to register on all
 *                  available interfaces. See "Constants for specifying an interface index" for more details.
 *
 * name:            If non-NULL, specifies the service name to be registered.
 *                  Most applications will not specify a name, in which case the computer
 *                  name is used (this name is communicated to the client via the callback).
 *                  If a name is specified, it must be 1-63 bytes of UTF-8 text.
 *                  If the name is longer than 63 bytes it will be automatically truncated
 *                  to a legal length, unless the NoAutoRename flag is set,
 *                  in which case kDNSServiceErr_BadParam will be returned.
 *
 * regtype:         The service type followed by the protocol, separated by a dot
 *                  (e.g. "_ftp._tcp"). The service type must be an underscore, followed
 *                  by 1-15 characters, which may be letters, digits, or hyphens.
 *                  The transport protocol must be "_tcp" or "_udp". New service types
 *                  should be registered at <http://www.dns-sd.org/ServiceTypes.html>.
 *
 *                  Additional subtypes of the primary service type (where a service
 *                  type has defined subtypes) follow the primary service type in a
 *                  comma-separated list, with no additional spaces, e.g.
 *                      "_primarytype._tcp,_subtype1,_subtype2,_subtype3"
 *                  Subtypes provide a mechanism for filtered browsing: A client browsing
 *                  for "_primarytype._tcp" will discover all instances of this type;
 *                  a client browsing for "_primarytype._tcp,_subtype2" will discover only
 *                  those instances that were registered with "_subtype2" in their list of
 *                  registered subtypes.
 *
 *                  The subtype mechanism can be illustrated with some examples using the
 *                  dns-sd command-line tool:
 *
 *                  % dns-sd -R Simple _test._tcp "" 1001 &
 *                  % dns-sd -R Better _test._tcp,HasFeatureA "" 1002 &
 *                  % dns-sd -R Best   _test._tcp,HasFeatureA,HasFeatureB "" 1003 &
 *
 *                  Now:
 *                  % dns-sd -B _test._tcp             # will find all three services
 *                  % dns-sd -B _test._tcp,HasFeatureA # finds "Better" and "Best"
 *                  % dns-sd -B _test._tcp,HasFeatureB # finds only "Best"
 *
 *                  Subtype labels may be up to 63 bytes long, and may contain any eight-
 *                  bit byte values, including zero bytes. However, due to the nature of
 *                  using a C-string-based API, conventional DNS escaping must be used for
 *                  dots ('.'), commas (','), backslashes ('\') and zero bytes, as shown below:
 *
 *                  % dns-sd -R Test '_test._tcp,s\.one,s\,two,s\\three,s\000four' local 123
 *
 *                  When a service is registered, all the clients browsing for the registered
 *                  type ("regtype") will discover it. If the discovery should be
 *                  restricted to a smaller set of well known peers, the service can be
 *                  registered with additional data (group identifier) that is known
 *                  only to a smaller set of peers. The group identifier should follow primary
 *                  service type using a colon (":") as a delimeter. If subtypes are also present,
 *                  it should be given before the subtype as shown below.
 *
 *                  % dns-sd -R _test1 _http._tcp:mygroup1 local 1001
 *                  % dns-sd -R _test2 _http._tcp:mygroup2 local 1001
 *                  % dns-sd -R _test3 _http._tcp:mygroup3,HasFeatureA local 1001
 *
 *                  Now:
 *                  % dns-sd -B _http._tcp:"mygroup1"                # will discover only test1
 *                  % dns-sd -B _http._tcp:"mygroup2"                # will discover only test2
 *                  % dns-sd -B _http._tcp:"mygroup3",HasFeatureA    # will discover only test3
 *
 *                  By specifying the group information, only the members of that group are
 *                  discovered.
 *
 *                  The group identifier itself is not sent in clear. Only a hash of the group
 *                  identifier is sent and the clients discover them anonymously. The group identifier
 *                  may be up to 256 bytes long and may contain any eight bit values except comma which
 *                  should be escaped.
 *
 * domain:          If non-NULL, specifies the domain on which to advertise the service.
 *                  Most applications will not specify a domain, instead automatically
 *                  registering in the default domain(s).
 *
 * host:            If non-NULL, specifies the SRV target host name. Most applications
 *                  will not specify a host, instead automatically using the machine's
 *                  default host name(s). Note that specifying a non-NULL host does NOT
 *                  create an address record for that host - the application is responsible
 *                  for ensuring that the appropriate address record exists, or creating it
 *                  via DNSServiceRegisterRecord().
 *
 * port:            The port, in network byte order, on which the service accepts connections.
 *                  Pass 0 for a "placeholder" service (i.e. a service that will not be discovered
 *                  by browsing, but will cause a name conflict if another client tries to
 *                  register that same name). Most clients will not use placeholder services.
 *
 * txtLen:          The length of the txtRecord, in bytes. Must be zero if the txtRecord is NULL.
 *
 * txtRecord:       The TXT record rdata. A non-NULL txtRecord MUST be a properly formatted DNS
 *                  TXT record, i.e. <length byte> <data> <length byte> <data> ...
 *                  Passing NULL for the txtRecord is allowed as a synonym for txtLen=1, txtRecord="",
 *                  i.e. it creates a TXT record of length one containing a single empty string.
 *                  RFC 1035 doesn't allow a TXT record to contain *zero* strings, so a single empty
 *                  string is the smallest legal DNS TXT record.
 *                  As with the other parameters, the DNSServiceRegister call copies the txtRecord
 *                  data; e.g. if you allocated the storage for the txtRecord parameter with malloc()
 *                  then you can safely free that memory right after the DNSServiceRegister call returns.
 *
 * callBack:        The function to be called when the registration completes or asynchronously
 *                  fails. The client MAY pass NULL for the callback -  The client will NOT be notified
 *                  of the default values picked on its behalf, and the client will NOT be notified of any
 *                  asynchronous errors (e.g. out of memory errors, etc.) that may prevent the registration
 *                  of the service. The client may NOT pass the NoAutoRename flag if the callback is NULL.
 *                  The client may still deregister the service at any time via DNSServiceRefDeallocate().
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
DNSServiceErrorType DNSSD_API DNSServiceRegister
(
    DNSServiceRef                       *sdRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    const char                          *name,         /* may be NULL */
    const char                          *regtype,
    const char                          *domain,       /* may be NULL */
    const char                          *host,         /* may be NULL */
    uint16_t port,                                     /* In network byte order */
    uint16_t txtLen,
    const void                          *txtRecord,    /* may be NULL */
    DNSServiceRegisterReply callBack,                  /* may be NULL */
    void                                *context       /* may be NULL */
);


/* DNSServiceAddRecord()
 *
 * Add a record to a registered service. The name of the record will be the same as the
 * registered service's name.
 * The record can later be updated or deregistered by passing the RecordRef initialized
 * by this function to DNSServiceUpdateRecord() or DNSServiceRemoveRecord().
 *
 * Note that the DNSServiceAddRecord/UpdateRecord/RemoveRecord are *NOT* thread-safe
 * with respect to a single DNSServiceRef. If you plan to have multiple threads
 * in your program simultaneously add, update, or remove records from the same
 * DNSServiceRef, then it's the caller's responsibility to use a mutex lock
 * or take similar appropriate precautions to serialize those calls.
 *
 * Parameters;
 *
 * sdRef:           A DNSServiceRef initialized by DNSServiceRegister().
 *
 * RecordRef:       A pointer to an uninitialized DNSRecordRef. Upon succesfull completion of this
 *                  call, this ref may be passed to DNSServiceUpdateRecord() or DNSServiceRemoveRecord().
 *                  If the above DNSServiceRef is passed to DNSServiceRefDeallocate(), RecordRef is also
 *                  invalidated and may not be used further.
 *
 * flags:           Currently ignored, reserved for future use.
 *
 * rrtype:          The type of the record (e.g. kDNSServiceType_TXT, kDNSServiceType_SRV, etc)
 *
 * rdlen:           The length, in bytes, of the rdata.
 *
 * rdata:           The raw rdata to be contained in the added resource record.
 *
 * ttl:             The time to live of the resource record, in seconds.
 *                  Most clients should pass 0 to indicate that the system should
 *                  select a sensible default value.
 *
 * return value:    Returns kDNSServiceErr_NoError on success, otherwise returns an
 *                  error code indicating the error that occurred (the RecordRef is not initialized).
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API DNSServiceAddRecord
(
    DNSServiceRef sdRef,
    DNSRecordRef                        *RecordRef,
    DNSServiceFlags flags,
    uint16_t rrtype,
    uint16_t rdlen,
    const void                          *rdata,
    uint32_t ttl
);


/* DNSServiceUpdateRecord
 *
 * Update a registered resource record. The record must either be:
 *   - The primary txt record of a service registered via DNSServiceRegister()
 *   - A record added to a registered service via DNSServiceAddRecord()
 *   - An individual record registered by DNSServiceRegisterRecord()
 *
 * Parameters:
 *
 * sdRef:           A DNSServiceRef that was initialized by DNSServiceRegister()
 *                  or DNSServiceCreateConnection().
 *
 * RecordRef:       A DNSRecordRef initialized by DNSServiceAddRecord, or NULL to update the
 *                  service's primary txt record.
 *
 * flags:           Currently ignored, reserved for future use.
 *
 * rdlen:           The length, in bytes, of the new rdata.
 *
 * rdata:           The new rdata to be contained in the updated resource record.
 *
 * ttl:             The time to live of the updated resource record, in seconds.
 *                  Most clients should pass 0 to indicate that the system should
 *                  select a sensible default value.
 *
 * return value:    Returns kDNSServiceErr_NoError on success, otherwise returns an
 *                  error code indicating the error that occurred.
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API DNSServiceUpdateRecord
(
    DNSServiceRef sdRef,
    DNSRecordRef RecordRef,                            /* may be NULL */
    DNSServiceFlags flags,
    uint16_t rdlen,
    const void                          *rdata,
    uint32_t ttl
);


/* DNSServiceRemoveRecord
 *
 * Remove a record previously added to a service record set via DNSServiceAddRecord(), or deregister
 * a record registered individually via DNSServiceRegisterRecord().
 *
 * Parameters:
 *
 * sdRef:           A DNSServiceRef initialized by DNSServiceRegister() (if the
 *                  record being removed was registered via DNSServiceAddRecord()) or by
 *                  DNSServiceCreateConnection() (if the record being removed was registered via
 *                  DNSServiceRegisterRecord()).
 *
 * recordRef:       A DNSRecordRef initialized by a successful call to DNSServiceAddRecord()
 *                  or DNSServiceRegisterRecord().
 *
 * flags:           Currently ignored, reserved for future use.
 *
 * return value:    Returns kDNSServiceErr_NoError on success, otherwise returns an
 *                  error code indicating the error that occurred.
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API DNSServiceRemoveRecord
(
    DNSServiceRef sdRef,
    DNSRecordRef RecordRef,
    DNSServiceFlags flags
);

// ???? Difference?

/*********************************************************************************************
*
*  Special Purpose Calls:
*  DNSServiceCreateConnection(), DNSServiceRegisterRecord(), DNSServiceReconfirmRecord()
*  (most applications will not use these)
*
*********************************************************************************************/

/* DNSServiceCreateConnection()
 *
 * Create a connection to the daemon allowing efficient registration of
 * multiple individual records.
 *
 * Parameters:
 *
 * sdRef:           A pointer to an uninitialized DNSServiceRef. Deallocating
 *                  the reference (via DNSServiceRefDeallocate()) severs the
 *                  connection and deregisters all records registered on this connection.
 *
 * return value:    Returns kDNSServiceErr_NoError on success, otherwise returns
 *                  an error code indicating the specific failure that occurred (in which
 *                  case the DNSServiceRef is not initialized).
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API DNSServiceCreateConnection(DNSServiceRef *sdRef);

/* DNSServiceRegisterRecord
 *
 * Register an individual resource record on a connected DNSServiceRef.
 *
 * Note that name conflicts occurring for records registered via this call must be handled
 * by the client in the callback.
 *
 * DNSServiceRegisterRecordReply() parameters:
 *
 * sdRef:           The connected DNSServiceRef initialized by
 *                  DNSServiceCreateConnection().
 *
 * RecordRef:       The DNSRecordRef initialized by DNSServiceRegisterRecord(). If the above
 *                  DNSServiceRef is passed to DNSServiceRefDeallocate(), this DNSRecordRef is
 *                  invalidated, and may not be used further.
 *
 * flags:           Currently unused, reserved for future use.
 *
 * errorCode:       Will be kDNSServiceErr_NoError on success, otherwise will
 *                  indicate the failure that occurred (including name conflicts.)
 *                  Other parameters are undefined if errorCode is nonzero.
 *
 * context:         The context pointer that was passed to the callout.
 *
 */

typedef void (DNSSD_API *DNSServiceRegisterRecordReply)
(
    DNSServiceRef sdRef,
    DNSRecordRef RecordRef,
    DNSServiceFlags flags,
    DNSServiceErrorType errorCode,
    void                                *context
);


/* DNSServiceRegisterRecord() Parameters:
 *
 * sdRef:           A DNSServiceRef initialized by DNSServiceCreateConnection().
 *
 * RecordRef:       A pointer to an uninitialized DNSRecordRef. Upon succesfull completion of this
 *                  call, this ref may be passed to DNSServiceUpdateRecord() or DNSServiceRemoveRecord().
 *                  (To deregister ALL records registered on a single connected DNSServiceRef
 *                  and deallocate each of their corresponding DNSServiceRecordRefs, call
 *                  DNSServiceRefDeallocate()).
 *
 * flags:           Possible values are kDNSServiceFlagsShared or kDNSServiceFlagsUnique
 *                  (see flag type definitions for details).
 *
 * interfaceIndex:  If non-zero, specifies the interface on which to register the record
 *                  (the index for a given interface is determined via the if_nametoindex()
 *                  family of calls.) Passing 0 causes the record to be registered on all interfaces.
 *                  See "Constants for specifying an interface index" for more details.
 *
 * fullname:        The full domain name of the resource record.
 *
 * rrtype:          The numerical type of the resource record (e.g. kDNSServiceType_PTR, kDNSServiceType_SRV, etc)
 *
 * rrclass:         The class of the resource record (usually kDNSServiceClass_IN)
 *
 * rdlen:           Length, in bytes, of the rdata.
 *
 * rdata:           A pointer to the raw rdata, as it is to appear in the DNS record.
 *
 * ttl:             The time to live of the resource record, in seconds.
 *                  Most clients should pass 0 to indicate that the system should
 *                  select a sensible default value.
 *
 * callBack:        The function to be called when a result is found, or if the call
 *                  asynchronously fails (e.g. because of a name conflict.)
 *
 * context:         An application context pointer which is passed to the callback function
 *                  (may be NULL).
 *
 * return value:    Returns kDNSServiceErr_NoError on success (any subsequent, asynchronous
 *                  errors are delivered to the callback), otherwise returns an error code indicating
 *                  the error that occurred (the callback is never invoked and the DNSRecordRef is
 *                  not initialized).
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API DNSServiceRegisterRecord
(
    DNSServiceRef sdRef,
    DNSRecordRef                        *RecordRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    const char                          *fullname,
    uint16_t rrtype,
    uint16_t rrclass,
    uint16_t rdlen,
    const void                          *rdata,
    uint32_t ttl,
    DNSServiceRegisterRecordReply callBack,
    void                                *context    /* may be NULL */
);


/* DNSServiceReconfirmRecord
 *
 * Instruct the daemon to verify the validity of a resource record that appears
 * to be out of date (e.g. because TCP connection to a service's target failed.)
 * Causes the record to be flushed from the daemon's cache (as well as all other
 * daemons' caches on the network) if the record is determined to be invalid.
 * Use this routine conservatively. Reconfirming a record necessarily consumes
 * network bandwidth, so this should not be done indiscriminately.
 *
 * Parameters:
 *
 * flags:           Not currently used.
 *
 * interfaceIndex:  Specifies the interface of the record in question.
 *                  The caller must specify the interface.
 *                  This API (by design) causes increased network traffic, so it requires
 *                  the caller to be precise about which record should be reconfirmed.
 *                  It is not possible to pass zero for the interface index to perform
 *                  a "wildcard" reconfirmation, where *all* matching records are reconfirmed.
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
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API DNSServiceReconfirmRecord
(
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    const char                         *fullname,
    uint16_t rrtype,
    uint16_t rrclass,
    uint16_t rdlen,
    const void                         *rdata
);
