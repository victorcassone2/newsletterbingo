Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]

  root "home#show"

  # Publisher administration, always scoped to an account the user belongs to.
  scope "a/:account_id", as: :account do
    get "", to: "publications#index", as: ""
    resource :account_profile, only: %i[ show ], path: "people"
    resources :publications, except: %i[ destroy ] do
      scope module: :publications do
        resource :today, only: %i[ show ], controller: "todays"
        resource :board_preview, only: %i[ show ]
        resource :analytics, only: %i[ show ]
        resources :words, only: %i[ index create ] do
          resource :archival, only: %i[ create destroy ], module: :words
        end
        resources :prizes, only: %i[ index update ]
        resource :sponsor, only: %i[ update ]
        resources :games, only: %i[ index show edit update ] do
          scope module: :games do
            resource :launch, only: %i[ create ]
            resources :issues, only: %i[ destroy ]
            resources :calls, only: %i[ edit update ] do
              resource :word, only: %i[ update ], module: :calls
              resource :position, only: %i[ update ], module: :calls
            end
          end
        end
      end
    end
  end

  # Public player experience. The newsletter link itself performs the claim.
  get "c/:public_code/today", to: "claims#create", as: :claim
  get "p/:public_code/board", to: "boards#show", as: :board
  get "p/:public_code/out/call/:id", to: "outbound_clicks#call", as: :call_outbound
  get "p/:public_code/out/prize/:id", to: "outbound_clicks#prize", as: :prize_outbound

  get "up" => "rails/health#show", as: :rails_health_check
end
