/*********************************************************************************************
*
* Unix Domain Socket access, DNSServiceRef deallocation, and data processing functions
*
*********************************************************************************************/

/* DNSServiceRefSockFD()
 *
 * Access underlying Unix domain socket for an initialized DNSServiceRef.
 * The DNS Service Discovery implementation uses this socket to communicate between the client and
 * the daemon. The application MUST NOT directly read from or write to this socket.
 * Access to the socket is provided so that it can be used as a kqueue event source, a CFRunLoop
 * event source, in a select() loop, etc. When the underlying event management subsystem (kqueue/
 * select/CFRunLoop etc.) indicates to the client that data is available for reading on the
 * socket, the client should call DNSServiceProcessResult(), which will extract the daemon's
 * reply from the socket, and pass it to the appropriate application callback. By using a run
 * loop or select(), results from the daemon can be processed asynchronously. Alternatively,
 * a client can choose to fork a thread and have it loop calling "DNSServiceProcessResult(ref);"
 * If DNSServiceProcessResult() is called when no data is available for reading on the socket, it
 * will block until data does become available, and then process the data and return to the caller.
 * The application is responsible for checking the return value of DNSServiceProcessResult()
 * to determine if the socket is valid and if it should continue to process data on the socket.
 * When data arrives on the socket, the client is responsible for calling DNSServiceProcessResult(ref)
 * in a timely fashion -- if the client allows a large backlog of data to build up the daemon
 * may terminate the connection.
 *
 * sdRef:           A DNSServiceRef initialized by any of the DNSService calls.
 *
 * return value:    The DNSServiceRef's underlying socket descriptor, or -1 on
 *                  error.
 */

DNSSD_EXPORT
dnssd_sock_t DNSSD_API DNSServiceRefSockFD(DNSServiceRef sdRef);


/* DNSServiceProcessResult()
 *
 * Read a reply from the daemon, calling the appropriate application callback. This call will
 * block until the daemon's response is received. Use DNSServiceRefSockFD() in
 * conjunction with a run loop or select() to determine the presence of a response from the
 * server before calling this function to process the reply without blocking. Call this function
 * at any point if it is acceptable to block until the daemon's response arrives. Note that the
 * client is responsible for ensuring that DNSServiceProcessResult() is called whenever there is
 * a reply from the daemon - the daemon may terminate its connection with a client that does not
 * process the daemon's responses.
 *
 * sdRef:           A DNSServiceRef initialized by any of the DNSService calls
 *                  that take a callback parameter.
 *
 * return value:    Returns kDNSServiceErr_NoError on success, otherwise returns
 *                  an error code indicating the specific failure that occurred.
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API DNSServiceProcessResult(DNSServiceRef sdRef);


/* DNSServiceRefDeallocate()
 *
 * Terminate a connection with the daemon and free memory associated with the DNSServiceRef.
 * Any services or records registered with this DNSServiceRef will be deregistered. Any
 * Browse, Resolve, or Query operations called with this reference will be terminated.
 *
 * Note: If the reference's underlying socket is used in a run loop or select() call, it should
 * be removed BEFORE DNSServiceRefDeallocate() is called, as this function closes the reference's
 * socket.
 *
 * Note: If the reference was initialized with DNSServiceCreateConnection(), any DNSRecordRefs
 * created via this reference will be invalidated by this call - the resource records are
 * deregistered, and their DNSRecordRefs may not be used in subsequent functions. Similarly,
 * if the reference was initialized with DNSServiceRegister, and an extra resource record was
 * added to the service via DNSServiceAddRecord(), the DNSRecordRef created by the Add() call
 * is invalidated when this function is called - the DNSRecordRef may not be used in subsequent
 * functions.
 *
 * Note: This call is to be used only with the DNSServiceRef defined by this API.
 *
 * sdRef:           A DNSServiceRef initialized by any of the DNSService calls.
 *
 */

DNSSD_EXPORT
void DNSSD_API DNSServiceRefDeallocate(DNSServiceRef sdRef);



#if _DNS_SD_LIBDISPATCH
/*
 * DNSServiceSetDispatchQueue
 *
 * Allows you to schedule a DNSServiceRef on a serial dispatch queue for receiving asynchronous
 * callbacks.  It's the clients responsibility to ensure that the provided dispatch queue is running.
 *
 * A typical application that uses CFRunLoopRun or dispatch_main on its main thread will
 * usually schedule DNSServiceRefs on its main queue (which is always a serial queue)
 * using "DNSServiceSetDispatchQueue(sdref, dispatch_get_main_queue());"
 *
 * If there is any error during the processing of events, the application callback will
 * be called with an error code. For shared connections, each subordinate DNSServiceRef
 * will get its own error callback. Currently these error callbacks only happen
 * if the daemon is manually terminated or crashes, and the error
 * code in this case is kDNSServiceErr_ServiceNotRunning. The application must call
 * DNSServiceRefDeallocate to free the DNSServiceRef when it gets such an error code.
 * These error callbacks are rare and should not normally happen on customer machines,
 * but application code should be written defensively to handle such error callbacks
 * gracefully if they occur.
 *
 * After using DNSServiceSetDispatchQueue on a DNSServiceRef, calling DNSServiceProcessResult
 * on the same DNSServiceRef will result in undefined behavior and should be avoided.
 *
 * Once the application successfully schedules a DNSServiceRef on a serial dispatch queue using
 * DNSServiceSetDispatchQueue, it cannot remove the DNSServiceRef from the dispatch queue, or use
 * DNSServiceSetDispatchQueue a second time to schedule the DNSServiceRef onto a different serial dispatch
 * queue. Once scheduled onto a dispatch queue a DNSServiceRef will deliver events to that queue until
 * the application no longer requires that operation and terminates it using DNSServiceRefDeallocate.
 *
 * service:         DNSServiceRef that was allocated and returned to the application, when the
 *                  application calls one of the DNSService API.
 *
 * queue:           dispatch queue where the application callback will be scheduled
 *
 * return value:    Returns kDNSServiceErr_NoError on success.
 *                  Returns kDNSServiceErr_NoMemory if it cannot create a dispatch source
 *                  Returns kDNSServiceErr_BadParam if the service param is invalid or the
 *                  queue param is invalid
 */

DNSSD_EXPORT
DNSServiceErrorType DNSSD_API DNSServiceSetDispatchQueue
(
    DNSServiceRef service,
    dispatch_queue_t queue
);
#endif //_DNS_SD_LIBDISPATCH

#if !defined(_WIN32)
typedef void (DNSSD_API *DNSServiceSleepKeepaliveReply)
(
    DNSServiceRef sdRef,
    DNSServiceErrorType errorCode,
    void                                *context
);
DNSSD_EXPORT
DNSServiceErrorType DNSSD_API DNSServiceSleepKeepalive
(
    DNSServiceRef                       *sdRef,
    DNSServiceFlags flags,
    int fd,
    unsigned int timeout,
    DNSServiceSleepKeepaliveReply callBack,
    void                                *context
);
#endif
