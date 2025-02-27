(defpackage #:cqlcl-test
  (:export #:concurrent-stream-ids)
  (:use :cl :cqlcl :fiveam :lparallel))

(in-package #:cqlcl-test)
(def-suite :cqlcl)
(in-suite :cqlcl)

(setf lparallel:*kernel* (lparallel:make-kernel 8)) ;; TOTALLY ARBIRARY

(defun hash-equal (h1 h2)
  (every (complement #'null) (maphash (lambda (k v)
                                        (is (equalp (gethash k h2) (values v t)))) h1)))

(test simple-connection
  (let* ((conn (make-connection))
         (conopt (gethash "COMPRESSION" (conn-options conn)))
         (expected (values '("lz4" "snappy") t)))
    (is (equal (sort conopt 'string<) expected))))

(test encode-decode-string-map
  (let* ((smap (cqlcl::alist-hash-table
                '(("KEYNAME" . "KEYVALUE")
                  ("KEYNAME2" . "KEYVALUE2")) :test #'equalp))
         (os (flexi-streams:make-in-memory-output-stream))
         (ims (flexi-streams:make-flexi-stream os)))
    (encode-value smap ims)
    (let* ((bv (flexi-streams:get-output-stream-sequence os))
           (is (make-stream-from-byte-vector bv))
           (parsed (parse-string-map is)))
      (hash-equal parsed smap))))

(test encode-decode-uuid
  (let* ((os (flexi-streams:make-in-memory-output-stream))
         (ims (flexi-streams:make-flexi-stream os))
         (u   (uuid:make-v4-uuid)))
    (encode-value u ims)
    (let* ((bv (flexi-streams:get-output-stream-sequence os))
           (is (make-stream-from-byte-vector bv))
           (parsed (parse-uuid is)))
      (is (uuid:uuid= parsed u)))))

(test encode-decode-consistency
  (maphash (lambda (k v)
             (declare (ignore v))
             (let* ((os (flexi-streams:make-in-memory-output-stream))
                    (ims (flexi-streams:make-flexi-stream os)))
               (encode-value k ims)
               (let* ((bv (flexi-streams:get-output-stream-sequence os))
                      (is (make-stream-from-byte-vector bv))
                      (parsed (parse-consistency is)))
                 (is (equalp parsed k)))))
           +consistency-name-to-digit+))

(test encode-decode-bytes
    (let* ((n 65536)
           (bv (make-array n :fill-pointer 0 :element-type '(unsigned-byte 8) :adjustable t))
           (os (flexi-streams:make-in-memory-output-stream))
           (ims (flexi-streams:make-flexi-stream os)))
      (dotimes (x n)
        (vector-push-extend (random 128) bv))
      (encode-value bv ims)
      (let* ((sbv (flexi-streams:get-output-stream-sequence os))
             (is (make-stream-from-byte-vector sbv))
             (parsed (parse-bytes is)))
        (is (equalp parsed bv)))))

(test encode-decode-short-bytes
    (let* ((n 65535)
           (bv (make-array n :fill-pointer 0 :element-type '(unsigned-byte 8) :adjustable t))
           (os (flexi-streams:make-in-memory-output-stream))
           (ims (flexi-streams:make-flexi-stream os)))
      (dotimes (x n)
        (vector-push-extend (random 128) bv))
      (encode-value bv ims)
      (let* ((sbv (flexi-streams:get-output-stream-sequence os))
             (is (make-stream-from-byte-vector sbv))
             (parsed (parse-short-bytes is)))
        (is (equalp parsed bv)))))

(test encode-decode-long-bytes
    (let* ((n 65536)
           (bv (make-array n :fill-pointer 0 :element-type '(unsigned-byte 8) :adjustable t))
           (os (flexi-streams:make-in-memory-output-stream))
           (ims (flexi-streams:make-flexi-stream os)))
      (dotimes (x n)
        (vector-push-extend (random 128) bv))
      (encode-value bv ims)
      (let* ((sbv (flexi-streams:get-output-stream-sequence os))
             (is (make-stream-from-byte-vector sbv))
             (parsed (parse-bytes is)))
        (is (equalp parsed bv)))))

(test encode-decode-int
  (loop for i in '(-65535 0 65535)
     do
       (let* ((os (flexi-streams:make-in-memory-output-stream))
              (ims (flexi-streams:make-flexi-stream os)))
         (write-int i ims)
         (let* ((bv (flexi-streams:get-output-stream-sequence os))
                (is (make-stream-from-byte-vector bv))
                (parsed (parse-int is)))
           (is (equalp parsed i))))))

(test encode-decode-boolean
    (dolist (el '(t nil))
      (let* ((os (flexi-streams:make-in-memory-output-stream))
             (ims (flexi-streams:make-flexi-stream os)))
        (encode-value el ims)
        (let* ((bv (flexi-streams:get-output-stream-sequence os))
               (is (make-stream-from-byte-vector bv))
               (parsed (parse-boolean is)))
          (is (equalp parsed el))))))

(test encode-decode-ip
    (let ((ip4 (make-ipv4 "192.168.0.1"))
          (ip6 (make-ipv6 "2001:db8:0000:1:1:1:1:1")))
      (dolist (el (list ip4 ip6))
        (let* ((os (flexi-streams:make-in-memory-output-stream))
               (ims (flexi-streams:make-flexi-stream os)))
          (encode-value el ims)
          (force-output ims)
          (let* ((bv (flexi-streams:get-output-stream-sequence os))
                 (is (make-stream-from-byte-vector bv))
                 (parsed (parse-ip is)))
            (is (ip= parsed el)))))))

(defun create-keyspace (keyspace)
  (format nil "CREATE KEYSPACE ~A
                          WITH replication = {
                              'class': 'SimpleStrategy', 'replication_factor': '1'
                          }"
          keyspace))

(defun drop-keyspace (keyspace)
  (format nil "DROP KEYSPACE ~A" keyspace))

(defun create-table (table-name)
  (format nil "CREATE TABLE ~A.test (
                          id uuid PRIMARY KEY,
                          name text,
                          value int
                      )"
          table-name))

(defun create-full-table (table-name)
  (format nil "CREATE TABLE ~A.fulltest (
                id int PRIMARY KEY,
                bigint bigint,
                blob blob,
                boolean boolean,
                inet inet,
                timestamp timestamp,
                timeuuid timeuuid,
                uuid uuid,
                varchar varchar,
                varint varint,
                list list<int>,
                aset set<int>,
                map map<int, text>)"
          table-name))

(defun insert-full-table (table-name)
   (format nil "INSERT INTO ~A.fulltest (
                id,
                ascii,
                bigint,
                blob,
                boolean,
                inet,
                timestamp,
                timeuuid,
                uuid,
                varchar,
                varint,
                list,
                aset,
                map) VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                table-name))

(defun drop-table (table-name)
  (format nil "DROP TABLE ~A.test" table-name))

(defun random-string ()
  (format nil "~{~A~}"
          (loop for i from 0 upto 10
             collect
               (code-char (+ (random 25) 65)))))

(test create/drop-keyspace
  (let* ((cxn (make-connection))
         (table-name (random-string))
         (create-keyspace (create-keyspace table-name))
         (drop-keyspace (drop-keyspace table-name)))
    (is (query cxn create-keyspace))
    (is (query cxn drop-keyspace))))

(test create/drop-tables
  (let* ((cxn (make-connection))
         (table-name (random-string))
         (create-keyspace (create-keyspace table-name))
         (drop-keyspace (drop-keyspace table-name))
         (create-table (create-table table-name))
         (drop-table (drop-table table-name)))
    (is (query cxn create-keyspace))
    (is (query cxn create-table))
    (is (query cxn drop-table))
    (is (query cxn drop-keyspace))))

(test querying-data
  (let* ((cxn (make-connection))
         (table-name (random-string))
         (create-keyspace (create-keyspace table-name))
         (drop-keyspace (drop-keyspace table-name))
         (create-table (create-table table-name))
         (drop-table (drop-table table-name)))
    (query cxn create-keyspace)
    (query cxn create-table)
    (is (not (query cxn (format nil "SELECT * FROM ~a.test" table-name))))
    (is (not (prepare cxn (format nil "INSERT INTO ~a.test (id, name, value) VALUES(?, ?, ?)" table-name))))
    (is (not (execute cxn (format nil "INSERT INTO ~a.test (id, name, value) VALUES(?, ?, ?)" table-name)
             (uuid:make-v4-uuid) "HELLO" 123)))
    (is (not (execute cxn (format nil "INSERT INTO ~a.test (id, name, value) VALUES(?, ?, ?)" table-name)
             (uuid:make-v4-uuid) "HELLO" 123)))
    (is (not (execute cxn (format nil "INSERT INTO ~a.test (id, name, value) VALUES(?, ?, ?)" table-name)
             (uuid:make-v4-uuid) "HELLO" 123)))
    (is (= (length (query cxn (format nil "SELECT * FROM ~a.test" table-name))) 3))
    (query cxn drop-table)
    (query cxn drop-keyspace)))

(test set-keyspace
  (let* ((cxn (make-connection))
         (table-name (random-string))
         (create-keyspace (create-keyspace table-name))
         (drop-keyspace (drop-keyspace table-name)))
    (is (query cxn create-keyspace))
    (is (query cxn (format nil "USE ~A" table-name)))
    (query cxn drop-keyspace)))

(test all-types-table
  (let* ((cxn (make-connection))
         (table-name (random-string))
         (create-keyspace (create-keyspace table-name))
         (drop-keyspace (drop-keyspace table-name))
         (create-table (create-full-table table-name))
         (insert (insert-full-table table-name))
         (uuid1 (uuid:make-uuid-from-string "85445cf8-93e0-11e3-bca1-425861b86ab6"))
         (uuid2 (uuid:make-uuid-from-string "92cf200b-672a-4c37-884d-b17206dcb096"))
         (blob-data (make-array
                     14
                     :element-type '(unsigned-byte 8)
                     :initial-contents #(48 120 65 49 66 50 67 51 68 52 69 53 70 54)))
         (ht (cqlcl::alist-hash-table
              '((1 . "SOMETHING")
                (2 . "whatever")
                (3 . "turds")) :test #'equalp)))
    (is (equal (query cxn create-keyspace) t))
    (is (equal (query cxn create-table) t))
    (is (equal (prepare cxn insert) nil))
    (is (not (execute cxn insert
                      1 "ascii" (make-bigint 123456) blob-data t (make-ipv4 "192.168.12.1") (make-bigint 1392207804464)
                      uuid1 uuid2
                      "varchar" (make-varint 123456) (list 1 2 3 4 5 6) (list 1 2 3 4 5 6)
                      ht)))
    (let* ((res (first (query cxn (format nil "SELECT * FROM ~A.fulltest" table-name))))
           (expected
            (list
             1 "ascii" (list 1 2 3 4 5 6) 123456 "0xA1B2C3D4E5F6" T (make-ipv4 "192.168.12.1")
             (list 1 2 3 4 5 6) ht 1392207804464
             uuid1 uuid2 "varchar" 123456))
          (comparitors
           (list #'= #'string= #'equal #'= #'string= #'eq #'ip= #'equal #'hash-equal
                 #'= #'uuid:uuid= #'uuid:uuid= #'string= #'=)))
      (loop for (a b f) in (mapcar #'list res expected comparitors)
         do
           (is (funcall f a b))))
    (is (equal (query cxn drop-keyspace) t))))

(test concurrent-stream-ids
  (let* ((client (make-connection :connection-type :async))
         (used-streams
          (lparallel:pmapcar #'next-stream-id (make-list 100 :initial-element client))))
    (is (equal (length used-streams) (length (used-streams client))))
    (is (equal (sort used-streams #'<) (sort (used-streams client) #'<)))))

(defun make-id-flipper (client)
  (let ((state nil)
        (id nil))
    (lambda ()
      (if state
          (return-stream-id client id)
          (setf id (next-stream-id client)))
      (setf state (not state)))))

(defun make-flipper-calls (flippers)
  (lparallel:pmapcar #'funcall flippers))

(test concurrent-stream-ids-checkin
  (let* ((client (make-connection :connection-type :async))
         (size 254)
         (flippers (loop for i from 1 to size
                        collect
                        (make-id-flipper client))))
    (loop for i from 1 to 15
         do
         (progn
           (is (= size (length (lparallel:pmapcar #'funcall flippers))))
           (is (= size (length (used-streams client))))
           (is (= size (length (lparallel:pmapcar #'funcall flippers))))
           (is (= 0 (length (used-streams client))))))))

(defun make-with-flipper (client)
  (lambda ()
    (with-next-stream-id foo client)))

(test with-next-stream-id-returns
  (let* ((client (make-connection :connection-type :async))
         (size 254)
         (flippers (loop for i from 1 to size
                        collect
                        (make-with-flipper client))))
    (lparallel:pmapcar #'funcall flippers)
    (is (= 0 (length (used-streams client))))))
