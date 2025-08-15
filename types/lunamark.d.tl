local record lunamark
    record writer
        record html
            record options
            end

            new: function(options?: options): html
        end
    end

    record reader
        record markdown
            record options
                fenced_code_blocks: boolean
            end

            new: function(writer: writer.html, options?: options): (function(text: string): string)
        end
    end
end

return lunamark
