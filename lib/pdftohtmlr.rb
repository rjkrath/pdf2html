# The library has a single method for converting PDF files into HTML. The
# method current takes in the source path, and either/both the user and owner
# passwords set on the source PDF document.  The convert method returns the
# HTML as a string for further manipulation of loading into a Document.
#
# Requires that pdftohtml be installed and on the path
#
# Author:: Kit Plummer (mailto:kitplummer@gmail.com)
# Copyright:: Copyright (c) 2009 Kit Plummer
# License:: MIT

# https://www.xpdfreader.com/pdftohtml-man.html

require 'rubygems'
require 'nokogiri'
require 'uri'
require 'open-uri'
require 'tempfile'

module PDFToHTMLR
  class PDFToHTMLRError < RuntimeError; end

  VERSION = '0.5.0'

  # Provides facilities for converting PDFs to HTML from Ruby code.
  class PdfFile
    attr :path, :target, :user_pwd, :owner_pwd, :format, :first_page_to_convert, :last_page_to_convert

    def initialize(pdf_path, target_path: nil, user_pwd: nil, owner_pwd: nil, first_page: nil, last_page: nil)
      @path = pdf_path
      @target = target_path
      @user_pwd = user_pwd
      @owner_pwd = owner_pwd
      @last_page_to_convert = last_page
      @first_page_to_convert = first_page
    end

    # Convert the PDF document to HTML.  Returns a string
    def convert
      opts = ['-stdout']

      opts << @format if @format
      opts << "-upw #{@user_pwd}" if @user_pwd
      opts << "-opw #{@owner_pwd}" if @owner_pwd
      opts << "\"#{@path}\""
      opts << "\"#{@target}\"" if @target

      output = `pdftohtml #{opts.join(" ")} 2>&1`

      if output.include?("Error: May not be a PDF file")
        raise PDFToHTMLRError, "Error: May not be a PDF file (continuing anyway)"
      elsif output.include?("Error:")
        raise PDFToHTMLRError, output.split("\n").first.to_s.chomp
      else
        output
      end
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

  # Handle a string-based local path as input, extends PdfFile
  class PdfFilePath < PdfFile
    def initialize(input_path, target_path: nil, user_pwd: nil, owner_pwd: nil, first_page: nil, last_page: nil)
      unless File.exist?(input_path)
        raise PDFToHTMLRError, "invalid file path"
      end

      super(input_path, target_path: target_path, user_pwd: user_pwd, owner_pwd: owner_pwd,
            first_page: first_page, last_page: last_page)
    end
  end

  # Handle a URI as a remote path to a PDF, extends PdfFile
  class PdfFileUrl < PdfFile
    def initialize(input_url, target_path: nil, user_pwd: nil, owner_pwd: nil, first_page: nil, last_page: nil)
      begin
        if (input_url =~ URI::regexp).nil?
          raise PDFToHTMLRError, "invalid file url"
        end

        tempfile = Tempfile.new('pdftohtmlr')
        File.open(tempfile.path, 'wb') { |f| f.write(open(input_url).read) }

        super(tempfile.path, target_path: target_path, user_pwd: user_pwd, owner_pwd: owner_pwd,
              first_page: first_page, last_page: last_page)
      rescue => bang
        raise PDFToHTMLRError, bang.to_s
      end
    end
  end
end
