local record lunamark
    record writer
        record html
            record options
            end

            blockquote: function(any): any
            div: function(any, {string: string}): any
            new: function(options?: options): html
        end
    end

    record reader
        record markdown
            record options
                fenced_code_blocks: boolean
                fenced_divs: boolean
                pipe_tables: boolean
            end

            new: function(writer: writer.html, options?: options): (function(text: string): string)
        end
    end
end

return lunamark
