// Culled from WebCore 7601.3.8 at http://www.opensource.apple.com/release/os-x-10112/

extern CFTypeID wkGetAXTextMarkerTypeID();
extern CFTypeID wkGetAXTextMarkerRangeTypeID();
// extern CFTypeRef (*wkCreateAXTextMarkerRange)(CFTypeRef start, CFTypeRef end);
// extern CFTypeRef (*wkCopyAXTextMarkerRangeStart)(CFTypeRef range);
// extern CFTypeRef (*wkCopyAXTextMarkerRangeEnd)(CFTypeRef range);
// extern CFTypeRef (*wkCreateAXTextMarker)(const void *bytes, size_t len);
// extern BOOL (*wkGetBytesFromAXTextMarker)(CFTypeRef textMarker, void *bytes, size_t length);

// still no joy... calling these crashes