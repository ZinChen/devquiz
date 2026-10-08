# Карточка участника live-активности: то, что видно по клику на аватарку.
# Только JSON — открывается поверх страницы, отдельной Inertia-страницы нет.
class ActivityUsersController < ApplicationController
  def show
    user = ActivityPresence.visible_user(params[:id])
    return head :not_found unless user

    render json: {
      id:           user.id,
      name:         user.name,
      avatar_url:   user.avatar_url,
      avatar_seed:  ActivityPresence.public_avatar_seed(user),
      achievements: AchievementsSummary.for(user: user).to_public_props
    }
  end
end
