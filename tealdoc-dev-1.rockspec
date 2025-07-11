rockspec_format = "3.0"
package = "tealdoc"
version = "dev-1"
source = {
   url = "git+https://github.com/teal-language/tealdoc.git",
   branch = "prototype"
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
   "tl > 0.24.6"
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
      ["tealdoc.tool.dump"] = "build/tealdoc/tool/dump.lua",
      ["tealdoc.tool.generator"] = "build/tealdoc/tool/generator.lua",
      ["tealdoc.tool.markdown"] = "build/tealdoc/tool/markdown.lua",
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
         ["tealdoc.tool.dump"] = "src/tealdoc/tool/dump.tl",
         ["tealdoc.tool.generator"] = "src/tealdoc/tool/generator.tl",
         ["tealdoc.tool.markdown"] = "src/tealdoc/tool/markdown.tl",
      },
      bin = {
         "bin/tealdoc"
      }
   }
}
