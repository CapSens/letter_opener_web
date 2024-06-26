# frozen_string_literal: true

module LetterOpenerWeb
  class BaseLetter
    attr_reader :id, :sent_at

    def initialize(params)
      @id      = params.fetch(:id)
      @sent_at = params[:sent_at]
    end

    def self.letters_location
      LetterOpenerWeb.config.letters_location
    end
    delegate :letters_location, to: :class

    def self.find(id)
      new(id: id)
    end

    def headers
      html = read_file(:rich) if style_exists?('rich')
      html ||= read_file(:plain)

      # NOTE: This is ugly, we should look into using nokogiri and making that a
      # dependency of this gem
      match_data = html.match(%r{<body>\s*<div[^>]+id="container">\s*<div[^>]+id="message_headers">\s*(<dl>.+</dl>)}m)
      return remove_attachments_link(match_data[1]).html_safe if match_data && match_data[1].present?

      'UNABLE TO PARSE HEADERS'
    end

    def plain_text
      @plain_text ||= adjust_link_targets(read_file(:plain))
    end

    def rich_text
      @rich_text ||= adjust_link_targets(read_file(:rich))
    end

    def to_param
      id
    end

    def default_style
      style_exists?('rich') ? 'rich' : 'plain'
    end

    private

    def remove_attachments_link(headers)
      xml = REXML::Document.new(headers)
      if xml.root.elements.size == 10
        xml.delete_element('//dd[last()]')
        xml.delete_element('//dt[last()]')
      end
      xml.to_s
    end

    def base_dir_within_letters_location?
      base_dir.to_s.start_with?(self.class.letters_location.to_s)
    end

    def adjust_link_targets(contents)
      # We cannot feed the whole file to a XML parser as some mails are
      # "complete" (as in they have the whole <html> structure) and letter_opener
      # prepends some information about the mail being sent, making REXML
      # complain about it
      contents.scan(%r{<a\s[^>]+>(?:.|\s)*?</a>}).each do |link|
        fixed_link = fix_link_html(link)
        xml        = REXML::Document.new(fixed_link).root
        next if xml.attributes['href'] =~ /(plain|rich).html/

        xml.attributes['target'] = '_blank'
        xml.add_text('') unless xml.text
        contents.gsub!(link, xml.to_s)
      end
      contents
    end

    def fix_link_html(link_html)
      # REFACTOR: we need a better way of fixing the link inner html
      link_html.dup.tap do |fixed_link|
        fixed_link.gsub!('<br>', '<br/>')
        fixed_link.scan(/<img(?:[^>]+?)>/).each do |img|
          fixed_img = img.dup
          fixed_img.gsub!(/>$/, '/>') unless img =~ %r{/>$}
          fixed_link.gsub!(img, fixed_img)
        end
      end
    end
  end
end
