(in-package :cqlcl)


(defmacro rev-hash (ht)
  (let ((ht-sym (gensym "hash-table"))
        (ht-orig (gensym "hash-table-orig"))
        (k (gensym))
        (v (gensym)))
    `(let* ((,ht-orig ,ht)
            (,ht-sym (make-hash-table :size (hash-table-count ,ht) :test #'equal)))
       (maphash (lambda (,k ,v)
                  (setf (gethash ,v ,ht-sym) ,k)) ,ht-orig)
       ,ht-sym)))

(defun make-stream-from-byte-vector (bv)
  (flexi-streams:make-flexi-stream
   (flexi-streams:make-in-memory-input-stream bv)))

(defun empty? (thing)
  (zerop (length thing)))


(defmacro while (condition &rest body)
  `(loop while ,condition
      do
        ,@body))

(defun drain-stream (stream)
  (let ((out nil))
    (while (listen stream)
      (push (read-byte stream) out))
    (reverse out)))

(defun juxt (&rest funs)
  (lambda (v)
    (mapcar (lambda (f)
              (funcall f v)) funs)))

(defun alist-hash-table (alist &rest hash-table-initargs)
  (let ((htable (apply 'make-hash-table hash-table-initargs)))
    (dolist (cons alist)
      (setf (gethash (car cons) htable) (cdr cons)))
    htable))
