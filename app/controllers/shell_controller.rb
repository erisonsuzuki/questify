class ShellController < ApplicationController
  def show
    response.headers["Cache-Control"] = "no-store"
    render html: Rails.root.join("public/app/index.html").read.html_safe
  end
end
