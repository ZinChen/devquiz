class BookmarksController < ApplicationController
  before_action :require_auth

  def create
    question = Question.find(params[:question_id])
    current_user.bookmarks.find_or_create_by!(question: question)
    render json: { bookmarked: true }
  end

  def destroy
    question = Question.find(params[:question_id])
    current_user.bookmarks.find_by(question: question)&.destroy
    render json: { bookmarked: false }
  end
end
