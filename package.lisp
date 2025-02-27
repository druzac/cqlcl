(defpackage :cqlcl
  (:use #:cl #:uuid #:split-sequence :lparallel :bordeaux-threads)
  (:export
   ;; API
   #:make-connection
   #:query
   #:prepare
   #:execute
   #:options

   #:msg

   ;; Exported for tests
   #:ip=
   #:+consistency-digit-to-name+
   #:+consistency-name-to-digit+
   #:conn-options
   #:encode-value
   #:make-ipv4
   #:make-ipv6
   #:make-bigint
   #:make-varint
   #:make-stream-from-byte-vector
   #:next-stream-id
   #:return-stream-id
   #:parse-boolean
   #:parse-bytes
   #:parse-consistency
   #:parse-int
   #:parse-ip
   #:parse-short
   #:parse-short-bytes
   #:parse-string
   #:parse-string-map
   #:parse-uuid
   #:used-streams
   #:with-next-stream-id
   #:write-int
   #:write-short))
