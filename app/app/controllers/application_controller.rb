class ApplicationController < ActionController::Base
  GUEST_TOKEN_COOKIE     = :guest_token
  GUEST_IDENTITY_COOKIE  = :guest_identity
  PREFERRED_TAGS_COOKIE  = :preferred_tags

  inertia_share do
    {
      current_user: current_user_props,
      guest_identity: current_user ? nil : GuestIdentity.from_cookie(cookies.signed[GUEST_IDENTITY_COOKIE]),
      flash: flash.to_h
    }
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  helper_method :current_user

  # Токен и личность гостя создаются лениво и вместе — только когда гость
  # действительно что-то делает (первая попытка, выбор тегов), чтобы не
  # ставить куки каждому посетителю, включая тех, кто просто листает список
  # тестов и ничего не проходит.
  def guest_token
    cookies.signed[GUEST_TOKEN_COOKIE]
  end

  def guest_token!
    cookies.signed[GUEST_TOKEN_COOKIE] ||= {
      value:    SecureRandom.uuid,
      expires:  1.year.from_now,
      httponly: true
    }
    guest_identity!
    guest_token
  end

  def guest_identity!
    cookies.signed[GUEST_IDENTITY_COOKIE] ||= {
      value:   GuestIdentity.generate.to_json,
      expires: 1.year.from_now
    }
  end

  # Предпочтения гостя живут в куке до логина, после — в users.preferred_tags.
  # nil в обоих случаях означает "экран выбора ещё не показывали".
  def preferred_tags
    return current_user.preferred_tags if current_user

    raw = cookies.signed[PREFERRED_TAGS_COOKIE]
    return nil if raw.blank?

    parsed = JSON.parse(raw)
    parsed.is_a?(Array) ? parsed : nil
  rescue JSON::ParserError
    nil
  end

  def preferred_tags=(tags)
    clean = TagTaxonomy.sanitize(tags)

    if current_user
      current_user.update!(preferred_tags: clean)
    else
      cookies.signed[PREFERRED_TAGS_COOKIE] = {
        value:   clean.to_json,
        expires: 1.year.from_now
      }
    end
  end

  def current_user_props
    return nil unless current_user
    {
      id:          current_user.id,
      name:        current_user.name,
      email:       current_user.email,
      avatar_url:  current_user.avatar_url,
      avatar_seed: current_user.avatar_seed,
      providers:   current_user.connected_providers
    }
  end

  def require_auth
    redirect_to login_path unless current_user
  end
end
