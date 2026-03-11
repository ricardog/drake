(require 'ert)
(require 'drake)

(ert-deftest drake-rust-module-load-test ()
  "Test if the rust module can be loaded and called."
  (require 'drake-rust-module)
  (should (fboundp 'drake-rust-module/render))
  (should (string= (drake-rust-module/render nil) "Rust render result")))

(provide 'rust-module-tests)
