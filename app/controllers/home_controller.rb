class HomeController < ApplicationController
  protect_from_forgery except: :create

  def index
  end
end
