module Rodauth
  LoginPasswordRequirementsBase = Feature.define(:login_password_requirements_base) do
    auth_value_method :login_confirm_param, 'login-confirm'
    auth_value_method :login_minimum_length, 3
    auth_value_method :logins_do_not_match_message, 'logins do not match'
    auth_value_method :password_confirm_param, 'password-confirm'
    auth_value_method :password_minimum_length, 6
    auth_value_method :passwords_do_not_match_message, 'passwords do not match'
    auth_value_method :require_email_address_logins?, true
    auth_value_method :require_login_confirmation?, true
    auth_value_method :require_password_confirmation?, true
    auth_value_method :same_as_existing_password_message, "invalid password, same as current password"

    auth_value_methods(
      :login_confirm_label,
      :login_does_not_meet_requirements_message,
      :login_too_short_message,
      :password_confirm_label,
      :password_does_not_meet_requirements_message,
      :password_hash_cost,
      :password_too_short_message
    )

    auth_methods(
      :login_meets_requirements?,
      :password_hash,
      :password_meets_requirements?,
      :set_password
    )

    def login_confirm_label
      "Confirm #{login_label}"
    end

    def password_confirm_label
      "Confirm #{password_label}"
    end

    attr_reader :login_requirement_message
    attr_reader :password_requirement_message

    def password_does_not_meet_requirements_message
      "invalid password, does not meet requirements#{" (#{password_requirement_message})" if password_requirement_message}"
    end

    def password_too_short_message
      "minimum #{password_minimum_length} characters"
    end

    def password_meets_requirements?(password)
      return true if password_minimum_length <= password.length
      @password_requirement_message = password_too_short_message
      false
    end
    
    def login_does_not_meet_requirements_message
      "invalid login#{", #{login_requirement_message}" if login_requirement_message}"
    end

    def login_too_short_message
      "minimum #{login_minimum_length} characters"
    end

    def login_meets_requirements?(login)
      login_meets_length_requirements?(login) && \
        login_meets_email_requirements?(login)
    end

    def login_meets_length_requirements?(login)
      return true if login_minimum_length <= login.length
      @login_requirement_message = login_too_short_message
      false
    end

    def login_meets_email_requirements?(login)
      return true unless require_email_address_logins?
      if login =~ /\A[^,;@ \r\n]+@[^,@; \r\n]+\.[^,@; \r\n]+\z/
        return true
      end
      @login_requirement_message = 'not a valid email address'
      return false
    end

    if ENV['RACK_ENV'] == 'test'
      def password_hash_cost
        BCrypt::Engine::MIN_COST
      end
    else
      # :nocov:
      def password_hash_cost
        BCrypt::Engine::DEFAULT_COST
      end
      # :nocov:
    end

    def password_hash(password)
      BCrypt::Password.create(password, :cost=>password_hash_cost)
    end

    def set_password(password)
      hash = password_hash(password)
      if account_password_hash_column
        account_ds.update(account_password_hash_column=>hash)
      elsif password_hash_ds.update(password_hash_column=>hash) == 0
        # This shouldn't raise a uniqueness error, as the update should only fail for a new user,
        # and an existing user shouldn't always havae a valid password hash row.  If this does
        # fail, retrying it will cause problems, it will override a concurrently running update
        # with potentially a different password.
        db[password_hash_table].insert(password_hash_id_column=>account_id, password_hash_column=>hash)
      end
      hash
    end

  end
end
