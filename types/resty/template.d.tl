local record Template
    root: string
    load: function(string, boolean): string
    process_file: function(string, {string: any}, string): string
    new: function({string: any}): Template
end

return Template
