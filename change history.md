**Version 01.00.08**

* altered s_dropobject to use new KV logging functionality
* removed error logging in s_KVLog, since it would create an endless cycle

**Version 01.00.07**

* changed code in legacy error and procedure logging procedures to utilize s_KVAdd and s_KVLog instead of writing to EventSink directly

**Version 01.00.06**

* added code to add data type information as xml attributes
* added audit framework revision to xml event

**Version 01.00.05**

* added code to encode invalid xml characters for eventsink
 
**Version 01.00.03 & 4**

* added deprecated feature to old audit.s_logxxx procedures
 
**Version 01.00.02** 

* added err_dt to error logging procedure
* added extra checking to versioning of upgrade scripts
* upgrade scripts will stop if version incorrect

**Version 01.00.01** 

* Renamed dbo.Look to dbo.v_Look

**Version 01.00.00**

* Created first versioned framework
