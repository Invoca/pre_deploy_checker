# frozen_string_literal: true

class ErrorsController < ApplicationController
  protect_from_forgery with: :null_session

  def bad_request
    @message = params['message']
    render(status: 400)
  end

  def not_found
    render(status: 404)
  end

  def internal_server_error
    render(status: 500)
  end
end
