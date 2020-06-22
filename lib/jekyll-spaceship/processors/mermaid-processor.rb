# frozen_string_literal: true

require "net/http"
require "base64"

module Jekyll::Spaceship
  class MermaidProcessor < Processor
    exclude :none

    def self.config
      {
        'mode' => 'default',
        'syntax' => {
          'code' => 'mermaid@render',
          'custom' => ['@startmermaid', '@endmermaid']
        },
        'css' => {
          'class' => 'mermaid'
        },
        'config': {
          'theme' => 'default'
        },
        'src' => 'https://mermaid.ink/img/'
      }
    end

    def on_handle_markdown(content)
      # match custom mermaid block and code block
      syntax = self.config['syntax']
      code_name = syntax['code']
      custom = syntax['custom'][-2, 2]

      patterns = [
        /((`{3,})\s*#{code_name}((?:.|\n)*?)\2)/,
        /((?<!\\)(#{custom[0]})((?:.|\n)*?)(?<!\\)(#{custom[1]}))/
      ]

      patterns.each do |pattern|
        content = handle_mermaid_block(pattern, content)
      end

      # handle escape custom mermaid block
      content.gsub(/\\(#{custom[0]}|#{custom[1]})/, '\1')
    end

    def handle_mermaid_block(pattern, content)
      content.scan pattern do |match|
        match = match.select { |m| not m.nil? }
        block = match[0]
        code = match[2]

        self.handled = true

        content = content.gsub(
          block,
          handle_mermaid(code)
        )
      end
      content
    end

    def handle_mermaid(code)
      # encode to UTF-8
      code = code.encode('UTF-8')

      # wrap code
      code = {
        'code' => code.gsub(/^\s*|\s*$/, ''),
        'mermaid' => config['config']
      }.to_json

      # encode to base64 string
      code = Base64.urlsafe_encode64(code, padding: false)
      url = get_url(code)

      # render mode
      case self.config['mode']
      when 'pre-fetch'
        url = self.get_mermaid_img_data(url)
      end

      # return img tag
      css_class = self.config['css']['class']
      "<img class=\"#{css_class}\" src=\"#{url}\">"
    end

    def get_url(code)
      "#{config['src']}#{code}"
    end

    def get_mermaid_img_data(url)
      data = ''
      begin
        data = Net::HTTP.get URI(url)
        data = Base64.encode64(data)
        data = "data:image/png;base64, #{data}"
      rescue StandardError => msg
        data = url
        logger.log msg
      end
      data
    end
  end
end
