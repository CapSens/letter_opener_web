# frozen_string_literal: true

module LetterOpenerWeb
  class AwsLetter < BaseLetter
    def self.aws_list_letters(path = [], **options)
      LetterOpenerWeb
        .aws_client
        .list_objects_v2(
          bucket: LetterOpenerWeb.config.aws_bucket,
          prefix: File.join([letters_location, *path].compact),
          **options
        )
    end
    delegate :aws_list_letters, to: :class

    def self.search
      letters = aws_list_letters(delimiter: '.html').common_prefixes.map do |prefix|
        new(id: File.basename(File.dirname(prefix.prefix)))
      end

      letters.uniq(&:id).reverse
    end

    def self.destroy_all
      letters = aws_list_letters.contents.map(&:key)

      LetterOpenerWeb.aws_client.delete_objects(
        bucket: LetterOpenerWeb.config.aws_bucket,
        delete: {
          objects: letters.map { |key| { key: key } },
          quiet: false
        }
      )
    end

    def attachments
      @attachments ||= aws_list_letters([id, 'attachments/']).contents.each_with_object({}) do |file, hash|
        hash[File.basename(file.key)] = attachment_url(file.key)
      end
    end

    def delete
      return unless valid?

      letters = aws_list_letters([id]).contents.map(&:key)

      LetterOpenerWeb.aws_client.delete_objects(
        bucket: LetterOpenerWeb.config.aws_bucket,
        delete: {
          objects: letters.map { |key| { key: key } },
          quiet: false
        }
      )
    end

    def valid?
      aws_list_letters([id]).contents.any?
    end

    private

    def attachment_url(key)
      bucket = Aws::S3::Bucket.new(
        name: LetterOpenerWeb.config.aws_bucket, client: LetterOpenerWeb.aws_client
      )

      obj = bucket.object(key)
      obj.presigned_url(:get, expires_in: 1.week.to_i)
    end

    def objects
      @objects ||= {}
    end

    def read_file(style)
      return objects[style] if objects.key?(style)

      response = LetterOpenerWeb.aws_client
                                .get_object(
                                  bucket: LetterOpenerWeb.config.aws_bucket,
                                  key: File.join(letters_location, id, "#{style}.html")
                                )

      response.body.read.tap do |value|
        objects[style] = value
      end
    rescue Aws::S3::Errors::NoSuchKey
      ''
    end

    def style_exists?(style)
      return !objects[style].empty? if objects.key?(style)

      objects[style] = read_file(style)
      !objects[style].empty?
    end
  end
end
