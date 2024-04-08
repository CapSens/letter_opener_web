# frozen_string_literal: true

require 'letter_opener_web/version'
require 'letter_opener_web/engine'
require 'rexml/document'
require 'aws-sdk-s3'

module LetterOpenerWeb
  class Config
    attr_accessor(
      :letters_storage,
      :aws_access_key_id,
      :aws_secret_access_key,
      :aws_region,
      :aws_bucket
    )

    def letters_location
      @letters_location ||=
        case LetterOpenerWeb.config.letters_storage
        when :local
          Rails.root.join('tmp', 'letter_opener')
        end
    end

    attr_writer :letters_location
  end

  def self.config
    @config ||= Config.new.tap do |conf|
      conf.letters_storage = :local
    end
  end

  def self.configure
    yield config if block_given?
  end

  def self.reset!
    @config = nil
    @aws_client = nil
    @letters_location = nil
  end

  def self.aws_client
    @aws_client ||= ::Aws::S3::Client.new(
      access_key_id: LetterOpenerWeb.config.aws_access_key_id,
      secret_access_key: LetterOpenerWeb.config.aws_secret_access_key,
      region: LetterOpenerWeb.config.aws_region
    )
  end
end
