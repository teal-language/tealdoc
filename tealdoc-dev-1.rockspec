rockspec_format = "3.0"
package = "tealdoc"
version = "dev-1"
source = {
   url = "git+https://github.com/teal-language/tealdoc.git",
   branch = "main"
}
description = {
   summary = "A documentation generator written in Teal",
   detailed = "Its primary function is to generate documentation for programs written in Teal, but it is extensible enough to support other languages.",
   homepage = "https://github.com/teal-language/tealdoc",
   license = "MIT",
   issues_url = "https://github.com/teal-language/tealdoc/issues"
}
dependencies = {
   "argparse",
   "tl >= 0.24.7",
   "lunamark",
   "LuaFileSystem"
}
build = {
   type = "builtin",
   modules = {
      ["tealdoc"] = "build/tealdoc.lua",
      ["tealdoc.main"] = "build/tealdoc/main.lua",
      ["tealdoc.cli"] = "build/tealdoc/cli.lua",
      ["tealdoc.comment_parser"] = "build/tealdoc/comment_parser.lua",
      ["tealdoc.default_env"] = "build/tealdoc/default_env.lua",
      ["tealdoc.log"] = "build/tealdoc/log.lua",
      ["tealdoc.parser.teal"] = "build/tealdoc/parser/teal.lua",
      ["tealdoc.parser.markdown"] = "build/tealdoc/parser/markdown.lua",
         ["tealdoc.dump"] = "build/tealdoc/dump.lua",
         ["tealdoc.generator"] = "build/tealdoc/generator.lua",
         ["tealdoc.generator.markdown"] = "build/tealdoc/generator/markdown.lua",
         ["tealdoc.generator.html.generator"] = "build/tealdoc/generator/html/generator.lua",
         ["tealdoc.generator.signatures"] = "build/tealdoc/generator/signatures.lua",
         ["tealdoc.generator.html.builder"] = "build/tealdoc/generator/html/builder.lua",
         ["tealdoc.generator.html.default_css"] = "build/tealdoc/generator/html/default_css.lua",
         ["tealdoc.generator.html.detailed_signature_phase"] = "build/tealdoc/generator/html/detailed_signature_phase.lua",
   },
   install = {
      lua = {
         ["tealdoc"] = "src/tealdoc.tl",
         ["tealdoc.main"] = "src/tealdoc/main.tl",
         ["tealdoc.cli"] = "src/tealdoc/cli.tl",
         ["tealdoc.comment_parser"] = "src/tealdoc/comment_parser.tl",
         ["tealdoc.default_env"] = "src/tealdoc/default_env.tl",
         ["tealdoc.log"] = "src/tealdoc/log.tl",
         ["tealdoc.parser.teal"] = "src/tealdoc/parser/teal.tl",
         ["tealdoc.parser.markdown"] = "src/tealdoc/parser/markdown.tl",
         ["tealdoc.dump"] = "src/tealdoc/dump.tl",
         ["tealdoc.generator"] = "src/tealdoc/generator.tl",
         ["tealdoc.generator.markdown"] = "src/tealdoc/generator/markdown.tl",
         ["tealdoc.generator.html.generator"] = "src/tealdoc/generator/html/generator.tl",
         ["tealdoc.generator.signatures"] = "src/tealdoc/generator/signatures.tl",
         ["tealdoc.generator.html.builder"] = "src/tealdoc/generator/html/builder.tl",
         ["tealdoc.generator.html.default_css"] = "src/tealdoc/generator/html/default_css.tl",
         ["tealdoc.generator.html.detailed_signature_phase"] = "src/tealdoc/generator/html/detailed_signature_phase.tl",
      },
      bin = {
         "bin/tealdoc"
      }
   }
}
