module DraftjsHtml
  class ToHtml
    BLOCK_TYPE_TO_HTML = {
      'unstyled' => 'p',
      'paragraph' => 'p',
      'header-one' => 'h1',
      'header-two' => 'h2',
      'header-three' => 'h3',
      'header-four' => 'h4',
      'header-five' => 'h5',
      'header-six' => 'h6',
      'blockquote' => 'blockquote',
      'code-block' => 'code',
      'ordered-list-item' => 'li',
      'unordered-list-item' => 'li',
    }.freeze
    BLOCK_TYPE_TO_HTML_WRAPPER = {
      'code-block' => 'pre',
      'ordered-list-item' => 'ol',
      'unordered-list-item' => 'ul',
    }.freeze
    STYLE_MAP = {
      'BOLD' => 'b',
      'ITALIC' => 'i',
    }.freeze

    def initialize(options)
      @document = Nokogiri::HTML::Builder.new
      @options = ensure_options!(options)
    end

    def convert(raw_draftjs)
      draftjs = Draftjs.parse(raw_draftjs)

      @document.html do |html|
        html.body do |body|
          @previous_parent = body.parent

          draftjs.blocks.each do |block|
            new_wrapper_tag = BLOCK_TYPE_TO_HTML_WRAPPER[block.type]
            if body.parent.name != new_wrapper_tag
              if new_wrapper_tag
                push_nesting(body, new_wrapper_tag)
              else
                pop_nesting(body)
              end
            end

            body.public_send(block_element_for(block)) do |block_body|
              block.each_range do |char_range|
                content = try_apply_entity_to(draftjs, char_range)

                apply_styles_to(block_body, char_range.style_names, content)
              end
            end
          end
        end
      end

      @document.doc.css('body').first.children.to_html.strip
    end

    private

    def apply_styles_to(html, style_names, text)
      return html.parent << text if style_names.empty?

      style, *rest = style_names
      html.public_send(style_element_for(style)) do
        apply_styles_to(html, rest, text)
      end
    end

    def block_element_for(block)
      @options[:block_type_mapping].fetch(block.type)
    end

    def style_element_for(style)
      @options[:inline_style_mapping][style]
    end

    def try_apply_entity_to(draftjs, char_range)
      entity = draftjs.find_entity(char_range.entity_key)
      content = char_range.text
      content = @options[:style_entity].call(entity, content) if entity
      content
    end

    def push_nesting(builder, tagname)
      node = create_child(builder, tagname)
      @previous_parent = builder.parent
      builder.parent = node
    end

    def pop_nesting(builder)
      builder.parent = @previous_parent
    end

    def create_child(builder, tagname)
      builder.parent.add_child(builder.doc.create_element(tagname))
    end

    def ensure_options!(opts)
      opts[:style_entity] ||= ->(_entity, chars) { chars }
      opts[:block_type_mapping] = BLOCK_TYPE_TO_HTML.merge(opts[:block_type_mapping] || {})
      opts[:inline_style_mapping] = STYLE_MAP.merge(opts[:inline_style_mapping] || {})
      opts
    end
  end
end
