# frozen_string_literal: true

module LetterOpenerWeb
  class Letter < BaseLetter
    def self.search
      letters = Dir.glob("#{letters_location}/*").map do |folder|
        new(id: File.basename(folder), sent_at: File.mtime(folder))
      end
      letters.sort_by(&:sent_at).reverse
    end

    def self.destroy_all
      FileUtils.rm_rf(letters_location)
    end

    def attachments
      @attachments ||= Dir["#{base_dir}/attachments/*"].each_with_object({}) do |file, hash|
        hash[File.basename(file)] = File.expand_path(file)
      end
    end

    def delete
      return unless valid?

      FileUtils.rm_rf(base_dir.to_s)
    end

    def valid?
      exists? && base_dir_within_letters_location?
    end

    private

    def style_exists?(style)
      File.exist?("#{base_dir}/#{style}.html")
    end

    def base_dir
      self.class.letters_location.join(id).cleanpath
    end

    def read_file(style)
      File.read("#{base_dir}/#{style}.html")
    end

    def exists?
      File.exist?(base_dir)
    end

    def base_dir_within_letters_location?
      base_dir.to_s.start_with?(self.class.letters_location.to_s)
    end
  end
end
