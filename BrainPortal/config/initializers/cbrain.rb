class CBRAIN

    public

    def self.filevault_dir  # TODO make it change with dev/prod/test env ?!?
        "public/data"
    end

    unless File.directory?(self.filevault_dir)
        raise "CBRAIN configuration error: file vault #{self.filevault_dir} does not exist!"
    end

end
