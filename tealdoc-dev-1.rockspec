rockspec_format = "3.0"
package = "tealdoc"
version = "dev-1"
source = {
   url = "git+https://github.com/teal-language/tealdoc.git"
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
      ["tealdoc.main"] = "build/main.lua",
      ["tealdoc.cli"] = "build/cli.lua",
      ["tealdoc.comment_parser"] = "build/comment_parser.lua",
      ["tealdoc.default_env"] = "build/default_env.lua",
      ["tealdoc.log"] = "build/log.lua",
      ["tealdoc.parser.teal"] = "build/parser/teal.lua",
      ["tealdoc.parser.markdown"] = "build/parser/markdown.lua",
      ["tealdoc.tool.dump"] = "build/tool/dump.lua",
      ["tealdoc.tool.generator"] = "build/tool/generator.lua",
      ["tealdoc.tool.markdown"] = "build/tool/markdown.lua",
   },
   install = {
      lua = {
         ["tealdoc"] = "src/tealdoc.tl",
         ["tealdoc.main"] = "src/main.tl",
         ["tealdoc.cli"] = "src/cli.tl",
         ["tealdoc.comment_parser"] = "src/comment_parser.tl",
         ["tealdoc.default_env"] = "src/default_env.tl",
         ["tealdoc.log"] = "src/log.tl",
         ["tealdoc.parser.teal"] = "src/parser/teal.tl",
         ["tealdoc.parser.markdown"] = "src/parser/markdown.tl",
         ["tealdoc.tool.dump"] = "src/tool/dump.tl",
         ["tealdoc.tool.generator"] = "src/tool/generator.tl",
         ["tealdoc.tool.markdown"] = "src/tool/markdown.tl",
      },
      bin = {
         "bin/tealdoc"
      }
   }
}
