class BookmarksController < ApplicationController
  before_action :require_auth

  def create
    question = Question.find(params[:question_id])
    current_user.bookmarks.find_or_create_by!(question: question)

    # Единственная ачивка, которая выдаётся не по итогам теста, — за
    # наполненное избранное. Страницы результата здесь нет, поэтому клиент
    # показывает её тостом (см. BookmarkButton).
    earned = AchievementsService.call(current_user)

    render json: {
      bookmarked: true,
      new_achievements: earned.map { |a| { slug: a.slug, title: a.title, icon: a.icon } }
    }
  end

  def destroy
    question = Question.find(params[:question_id])
    current_user.bookmarks.find_by(question: question)&.destroy
    render json: { bookmarked: false }
  end
end
