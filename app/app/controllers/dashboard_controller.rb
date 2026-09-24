class DashboardController < ApplicationController
  include DashboardRenderable

  before_action :require_auth

  PAGE_SIZE = DashboardRenderable::DASHBOARD_PAGE_SIZE

  def index
    render_dashboard
  end

  # Профиль сохраняется тем же PATCH /dashboard, а не отдельным маршрутом:
  # форма профиля живёт на этой странице, и Inertia запоминает URL из ответа
  # (request.original_fullpath) как текущий адрес браузера. Если бы сохранение
  # шло на /profile, адресная строка переключилась бы на /profile, а обновление
  # страницы там давало бы 404 — такого маршрута для GET нет.
  # avatar_url намеренно может прийти пустым — это «убрать URL, вернуться к
  # сгенерированному аватару», а не пропуск поля. Пустое name отклоняем
  # мягко (без 500): кнопка «Сохранить» и так заблокирована на пустом поле
  # на клиенте, но прямой запрос не должен ронять сервер.
  def update
    if current_user.update(profile_params)
      render_dashboard
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render_dashboard
    end
  end

  # Следующая страница истории.
  def attempts
    scope = completed_attempts
    render json: {
      attempts: attempt_props(scope.offset(page_offset).limit(PAGE_SIZE)),
      has_more: scope.count > page_offset + PAGE_SIZE
    }
  end

  # Следующая страница избранных вопросов.
  def bookmarks
    scope = user_bookmarks
    render json: {
      bookmarks: bookmark_props(scope.offset(page_offset).limit(PAGE_SIZE)),
      has_more:  scope.count > page_offset + PAGE_SIZE
    }
  end

  private

  def page_offset
    params[:offset].to_i.clamp(0, 100_000)
  end

  def profile_params
    params.permit(:name, :avatar_url, :avatar_seed)
  end
end
