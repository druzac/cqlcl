(in-package #:cl-user)

#+sbcl
(require :sb-cover)

#+sbcl
(progn
  (declaim (optimize sb-cover:store-coverage-data))
  (asdf:oos 'asdf:load-op :cqlcl :force t))

(ql:quickload :cqlcl)
(asdf:test-system :cqlcl)

#+sbcl
(progn
  (sb-cover:report "./coverage/")
  (declaim (optimize (sb-cover:store-coverage-data 0))))
