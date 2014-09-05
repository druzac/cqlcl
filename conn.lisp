(in-package :cqlcl)


(defclass synchronous-connection ()
  ;; TODO maybe this should hold an instance of a parser
  ((conn :accessor conn :initarg :conn)
   (prepared-queries :accessor pqs :initform (make-hash-table :test #'equal))
   (conn-options :accessor conn-options :initarg :options)))

(defun make-connection (&key (synchronous t) (host "localhost") (port 9042)); TODO: &key version compression)
  (let ((conn (usocket:socket-stream
               (usocket:socket-connect host port :element-type '(unsigned-byte 8)))))
    (options conn)
    (let* ((options (read-single-packet conn))
           (cxn-type (if synchronous 'synchronous-connection 'connection))
           (cxn (make-instance cxn-type :conn conn :options options)))
      (startup conn)
      (assert (eq (read-single-packet conn) :ready))
      cxn)))

(defgeneric prepare-statement (connection statement)
  (:documentation "Prepares a statement."))

(defgeneric query (connection statement)
  (:documentation "Executes a query."))

(defmethod prepare-statement ((conn synchronous-connection) (statement string))
  (when (not (gethash statement (pqs conn)))
    (let ((cxn (conn conn)))
      (prepare cxn statement)
      (let ((prep-results (read-single-packet cxn)))
        (setf (gethash statement (pqs conn)) prep-results))))
  (values))

(defmethod query ((conn synchronous-connection) (statement string))
  (let* ((cxn (conn conn)))
    (query* cxn statement)
    (read-single-packet cxn)))
