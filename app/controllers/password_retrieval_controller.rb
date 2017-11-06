class PasswordRetrievalController < ApplicationController
  def action_allowed?
    true
  end

  def forgotten
    render template: "password_retrieval/forgotten"
  end

  def send_password
    if params[:user][:email].nil? || params[:user][:email].strip.empty?
      flash[:error] = "Please enter an e-mail address."
    else
      user = User.find_by_email(params[:user][:email])
      if user
        url_format = "/password_edit/check_reset_url?token="
        token = SecureRandom.urlsafe_base64
        PasswordReset.save_token(user, token)
        url = self.request.base_url + url_format + token
        MailerHelper.send_mail_to_user(user, "Expertiza password reset", "send_password", url).deliver
        flash[:success] = "A link to reset your password has been sent to your e-mail address."
        redirect_to "/"
      else
        flash[:error] = "No account is associated with the e-mail address: \"" + params[:user][:email] + "\". Please try again."
        render template: "password_retrieval/forgotten"
      end
    end
  end

  # The token obtained from the reset url is first checked if it is valid ( if actually generated by the application), then checks if the token is active.
  def check_reset_url
    if params[:token].nil?
      flash[:error] = "Password reset page can only be accessed with a generated link, sent to your email"
      render template: "password_retrieval/forgotten"
    else
      @token = Digest::SHA1.hexdigest(params[:token])
      password_reset = PasswordReset.find_by(token: @token)
      if password_reset
        # URL expires after 1 day
        expired_url = password_reset.updated_at + 1.day
        if Time.now < expired_url
          #redirect_to action: 'reset_password', email: password_reset.user_email
          @email = password_reset.user_email
          render template: "password_retrieval/reset_password"
        else
          flash[:error] = "Link expired . Please request to reset password again"
          render template: "password_retrieval/forgotten"
        end
      else
        flash[:error] = "Link either expired or wrong Token. Please request to reset password again"
        render template: "password_retrieval/forgotten"
      end
    end
  end

  # avoid users to access this page without a valid token
  def reset_password
    flash[:error] = "Password reset page can only be accessed with a generated link, sent to your email"
    render template: "password_retrieval/forgotten"
  end

  # called after entering password and repassword, checks for validation and updates the password of the email
  def update_password
    if params[:reset][:password] == params[:reset][:repassword]
      user=User.find_by(:email => params[:reset][:email])
      user.password = params[:reset][:password]
      user.password_confirmation = params[:reset][:repassword]
      if user.save
        PasswordReset.delete_all(:user_email => user.email)
        flash[:success] = "Reset password success"
        redirect_to "/"
      else
        flash[:error] = "Password cannot be updated. Please try again"
        redirect_to "/"
      end
    else
      flash[:error] = "Password and confirm-password do not match. Try again"
      @email = params[:reset][:email]
      render template: "password_retrieval/reset_password"
    end
  end

end
