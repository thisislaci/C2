module ApplicationHelper
  # Variation of http://git.io/ugBzaQ
  def humanized_options_for_select(options)
    options = options.map do |val|
      [val.humanize, val]
    end
    options_for_select(options)
  end

  def controller_name
    params[:controller].gsub(/\W/, '-')
  end

  def bootstrap_alert_class(key)
    suffix = case key.to_sym
      when :notice
        'info'
      when :error
        'danger'
      else
        key
      end

    "bg-#{suffix}"
  end

  def flash_message(val)
    if val.is_a?(Enumerable)
      val.join('. ')
    else
      val
    end
  end

  def flash_list
    flash.map do |key, val|
      [key, flash_message(val)]
    end
  end

  def excluded_portal_link
    controller_name == 'home' ||
    current_page?(carts_path)
  end

  def client_partial(client_name, path, args={})
    to_check = client_name + "/" + path
    if lookup_context.template_exists?(to_check, [], true)
      args[:partial] = to_check
      render(args)
    else
      ""
    end
  end
end
