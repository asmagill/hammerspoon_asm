/*********************************************************************************************
*
*  NAT Port Mapping
*
*********************************************************************************************/

/* DNSServiceNATPortMappingCreate
 *
 * Request a port mapping in the NAT gateway, which maps a port on the local machine
 * to an external port on the NAT. The NAT should support either PCP, NAT-PMP or the
 * UPnP/IGD protocol for this API to create a successful mapping. Note that this API
 * currently supports IPv4 addresses/mappings only. If the NAT gateway supports PCP and
 * returns an IPv6 address (incorrectly, since this API specifically requests IPv4
 * addresses), the DNSServiceNATPortMappingReply callback will be invoked with errorCode
 * kDNSServiceErr_NATPortMappingUnsupported.
 *
 * The port mapping will be renewed indefinitely until the client process exits, or
 * explicitly terminates the port mapping request by calling DNSServiceRefDeallocate().
 * The client callback will be invoked, informing the client of the NAT gateway's
 * external IP address and the external port that has been allocated for this client.
 * The client should then record this external IP address and port using whatever
 * directory service mechanism it is using to enable peers to connect to it.
 * (Clients advertising services using Wide-Area DNS-SD DO NOT need to use this API
 * -- when a client calls DNSServiceRegister() NAT mappings are automatically created
 * and the external IP address and port for the service are recorded in the global DNS.
 * Only clients using some directory mechanism other than Wide-Area DNS-SD need to use
 * this API to explicitly map their own ports.)
 *
 * It's possible that the client callback could be called multiple times, for example
 * if the NAT gateway's IP address changes, or if a configuration change results in a
 * different external port being mapped for this client. Over the lifetime of any long-lived
 * port mapping, the client should be prepared to handle these notifications of changes
 * in the environment, and should update its recorded address and/or port as appropriate.
 *
 * NOTE: There are two unusual aspects of how the DNSServiceNATPortMappingCreate API works,
 * which were intentionally designed to help simplify client code:
 *
 *  1. It's not an error to request a NAT mapping when the machine is not behind a NAT gateway.
 *     In other NAT mapping APIs, if you request a NAT mapping and the machine is not behind a NAT
 *     gateway, then the API returns an error code -- it can't get you a NAT mapping if there's no
 *     NAT gateway. The DNSServiceNATPortMappingCreate API takes a different view. Working out
 *     whether or not you need a NAT mapping can be tricky and non-obvious, particularly on
 *     a machine with multiple active network interfaces. Rather than make every client recreate
 *     this logic for deciding whether a NAT mapping is required, the PortMapping API does that
 *     work for you. If the client calls the PortMapping API when the machine already has a
 *     routable public IP address, then instead of complaining about it and giving an error,
 *     the PortMapping API just invokes your callback, giving the machine's public address
 *     and your own port number. This means you don't need to write code to work out whether
 *     your client needs to call the PortMapping API -- just call it anyway, and if it wasn't
 *     necessary, no harm is done:
 *
 *     - If the machine already has a routable public IP address, then your callback
 *       will just be invoked giving your own address and port.
 *     - If a NAT mapping is required and obtained, then your callback will be invoked
 *       giving you the external address and port.
 *     - If a NAT mapping is required but not obtained from the local NAT gateway,
 *       or the machine has no network connectivity, then your callback will be
 *       invoked giving zero address and port.
 *
 *  2. In other NAT mapping APIs, if a laptop computer is put to sleep and woken up on a new
 *     network, it's the client's job to notice this, and work out whether a NAT mapping
 *     is required on the new network, and make a new NAT mapping request if necessary.
 *     The DNSServiceNATPortMappingCreate API does this for you, automatically.
 *     The client just needs to make one call to the PortMapping API, and its callback will
 *     be invoked any time the mapping state changes. This property complements point (1) above.
 *     If the client didn't make a NAT mapping request just because it determined that one was
 *     not required at that particular moment in time, the client would then have to monitor
 *     for network state changes to determine if a NAT port mapping later became necessary.
 *     By unconditionally making a NAT mapping request, even when a NAT mapping not to be
 *     necessary, the PortMapping API will then begin monitoring network state changes on behalf of
 *     the client, and if a NAT mapping later becomes necessary, it will automatically create a NAT
 *     mapping and inform the client with a new callback giving the new address and port information.
 *
 * DNSServiceNATPortMappingReply() parameters:
 *
 * sdRef:           The DNSServiceRef initialized by DNSServiceNATPortMappingCreate().
 *
 * flags:           Currently unused, reserved for future use.
 *
 * interfaceIndex:  The interface through which the NAT gateway is reached.
 *
 * errorCode:       Will be kDNSServiceErr_NoError on success.
 *                  Will be kDNSServiceErr_DoubleNAT when the NAT gateway is itself behind one or
 *                  more layers of NAT, in which case the other parameters have the defined values.
 *                  For other failures, will indicate the failure that occurred, and the other
 *                  parameters are undefined.
 *
 * externalAddress: Four byte IPv4 address in network byte order.
 *
 * protocol:        Will be kDNSServiceProtocol_UDP or kDNSServiceProtocol_TCP or both.
 *
 * internalPort:    The port on the local machine that was mapped.
 *
 * externalPort:    The actual external port in the NAT gateway that was mapped.
 *                  This is likely to be different than the requested external port.
 *
 * ttl:             The lifetime of the NAT port mapping created on the gateway.
 *                  This controls how quickly stale mappings will be garbage-collected
 *                  if the client machine crashes, suffers a power failure, is disconnected
 *                  from the network, or suffers some other unfortunate demise which
 *                  causes it to vanish without explicitly removing its NAT port mapping.
 *                  It's possible that the ttl value will differ from the requested ttl value.
 *
 * context:         The context pointer that was passed to the callout.
 *
 */

typedef void (DNSSD_API *DNSServiceNATPortMappingReply)
(
    DNSServiceRef sdRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    DNSServiceErrorType errorCode,
    uint32_t externalAddress,                           /* four byte IPv4 address in network byte order */
    DNSServiceProtocol protocol,
    uint16_t internalPort,                              /* In network byte order */
    uint16_t externalPort,                              /* In network byte order and may be different than the requested port */
    uint32_t ttl,                                       /* may be different than the requested ttl */
    void                             *context
);


/* DNSServiceNATPortMappingCreate() Parameters:
 *
 * sdRef:           A pointer to an uninitialized DNSServiceRef. If the call succeeds then it
 *                  initializes the DNSServiceRef, returns kDNSServiceErr_NoError, and the nat
 *                  port mapping will last indefinitely until the client terminates the port
 *                  mapping request by passing this DNSServiceRef to DNSServiceRefDeallocate().
 *
 * flags:           Currently ignored, reserved for future use.
 *
 * interfaceIndex:  The interface on which to create port mappings in a NAT gateway. Passing 0 causes
 *                  the port mapping request to be sent on the primary interface.
 *
 * protocol:        To request a port mapping, pass in kDNSServiceProtocol_UDP, or kDNSServiceProtocol_TCP,
 *                  or (kDNSServiceProtocol_UDP | kDNSServiceProtocol_TCP) to map both.
 *                  The local listening port number must also be specified in the internalPort parameter.
 *                  To just discover the NAT gateway's external IP address, pass zero for protocol,
 *                  internalPort, externalPort and ttl.
 *
 * internalPort:    The port number in network byte order on the local machine which is listening for packets.
 *
 * externalPort:    The requested external port in network byte order in the NAT gateway that you would
 *                  like to map to the internal port. Pass 0 if you don't care which external port is chosen for you.
 *
 * ttl:             The requested renewal period of the NAT port mapping, in seconds.
 *                  If the client machine crashes, suffers a power failure, is disconnected from
 *                  the network, or suffers some other unfortunate demise which causes it to vanish
 *                  unexpectedly without explicitly removing its NAT port mappings, then the NAT gateway
 *                  will garbage-collect old stale NAT port mappings when their lifetime expires.
 *                  Requesting a short TTL causes such orphaned mappings to be garbage-collected
 *                  more promptly, but consumes system resources and network bandwidth with
 *                  frequent renewal packets to keep the mapping from expiring.
 *                  Requesting a long TTL is more efficient on the network, but in the event of the
 *                  client vanishing, stale NAT port mappings will not be garbage-collected as quickly.
 *                  Most clients should pass 0 to use a system-wide default value.
 *
 * callBack:        The function to be called when the port mapping request succeeds or fails asynchronously.
 *
 * context:         An application context pointer which is passed to the callback function
 *                  (may be NULL).
 *
 * return value:    Returns kDNSServiceErr_NoError on success (any subsequent, asynchronous
 *                  errors are delivered to the callback), otherwise returns an error code indicating
 *                  the error that occurred.
 *
 *                  If you don't actually want a port mapped, and are just calling the API
 *                  because you want to find out the NAT's external IP address (e.g. for UI
 *                  display) then pass zero for protocol, internalPort, externalPort and ttl.
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API DNSServiceNATPortMappingCreate
(
    DNSServiceRef                    *sdRef,
    DNSServiceFlags flags,
    uint32_t interfaceIndex,
    DNSServiceProtocol protocol,                        /* TCP and/or UDP          */
    uint16_t internalPort,                              /* network byte order      */
    uint16_t externalPort,                              /* network byte order      */
    uint32_t ttl,                                       /* time to live in seconds */
    DNSServiceNATPortMappingReply callBack,
    void                             *context           /* may be NULL             */
);
