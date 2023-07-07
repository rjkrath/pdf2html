# https://www.xpdfreader.com/pdftohtml-man.html -> 2011 directions only (poppler base)

module Pdf2Html
  class PdfFile
    attr :path, :target_directory, :user_pwd, :owner_pwd, :format,
         :first_page_to_convert, :last_page_to_convert

    def self.convert_from_file_path!(path, **opts)
      unless File.exist?(path)
        raise StandardError, "Invalid file path"
      end

      new(path, **opts).convert
    end

    def self.convert_from_url!(url, **opts)
      begin
        URI(url)
      rescue => e
        raise StandardError, "Invalid file url #{e.message}"
      end

      begin
        stream = open(url)&.read
      rescue => e
        raise StandardError, "Error on reading url #{e.message}"
      end

      return unless stream

      tmpfile = Tempfile.new
      File.open(tmpfile.path, 'wb') { |f| f.write(stream) }

      new(tmpfile.path, **opts).convert
    end

    def initialize(pdf_path, target_directory: nil,
                   user_pwd: nil, owner_pwd: nil, first_page: nil, last_page: nil)
      @path = pdf_path
      @target_directory = target_directory
      @user_pwd = user_pwd
      @owner_pwd = owner_pwd
      @last_page_to_convert = last_page
      @first_page_to_convert = first_page
    end

    # Convert the PDF document to HTML.  Returns an html string
    # Shouldn't return a string - should return a file, no?
    def convert
      opts = ['-stdout']

      opts << @format if @format
      opts << "-upw #{@user_pwd}" if @user_pwd
      opts << "-opw #{@owner_pwd}" if @owner_pwd
      opts << "\"#{@path}\""
      opts << "\"#{File.join(@target_directory, File.basename(@path, '.*'))}\"" if @target_directory

      # 2>&1 means redirect the stderr (>2) to where stdout is being redirected to (&1)
      output = `pdftohtml #{opts.join(" ")} 2>&1`

      if output.include?("Error: May not be a PDF file")
        raise StandardError, "Error: May not be a PDF file (continuing anyway)"
      elsif output.include?("Error:")
        raise StandardError, output.split("\n").first.to_s.chomp
      end

      output_file_path = File.join(@target_directory,
                                   "#{File.basename(@path, '.*')}.#{@format == '-xml' ? 'xml' : 'html'}")

      File.open(output_file_path, 'wb') { |f| f.write(output) }
      output
    end

    # Convert the PDF document to HTML.  Returns a Nokogiri::HTML:Document
    def convert_to_document
      Nokogiri::HTML.parse(convert)
    end

    def convert_to_xml
      @format = "-xml"
      convert
    end

    def convert_to_xml_document
      @format = "-xml"
      Nokogiri::XML.parse(convert)
    end
  end
end
