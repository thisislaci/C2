class ApplicationController < ActionController::Base
  helper TimeHelper

  protect_from_forgery with: :exception
  helper_method :current_user, :signed_in?

  private

  def current_user
    @current_user ||= User.find_or_create_by(email_address: session[:user]['email']) if session[:user] && session[:user]['email']
  end

  def sign_in(user)
    session[:user] ||= {}
    session[:user]['email'] = user.email_address
    @current_user = user
  end

  def sign_out
    reset_session
    @current_user = nil
  end

  def signed_in?
    !!current_user
  end

  def authenticate_user!
    unless signed_in?
      session[:return_to] = request.fullpath
      redirect_to root_url, :alert => 'You need to sign in for access to this page.'
    end
  end
end
