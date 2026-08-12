class PreferencesController < ApplicationController
  # Страница доступна и гостю: его выбор уже хранится в куке, странно было бы
  # дать выбрать темы и не дать их поменять.
  def edit
    render inertia: "Settings/Tags", props: {
      preferred_tags:   preferred_tags || [],
      tag_categories:   TagTaxonomy.categories,
      tag_descriptions: TagTaxonomy.descriptions
    }
  end

  # Работает и для гостя: до логина выбор уходит в подписанную куку, после
  # входа SessionsController переносит его в профиль.
  def update
    self.preferred_tags = params[:tags]

    # Флеш здесь не ставим: запрос идёт с preserveState, страница не
    # перерисовывается, и уведомление показывает сам диалог (см. useToasts).
    # Иначе при первом изменении после перезагрузки всплывали бы два тоста.
    redirect_back fallback_location: root_path
  end
end
