FROM node:26.12.1-bookworm-slim AS node
FROM ruby:4.0.9-slim AS tools

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential libpq-dev git curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && gem install bundler -v 4.0.23 --no-document
WORKDIR /app
ENV BUNDLE_PATH=/bundle
CMD ["bin/rails", "server", "-b", "0.0.0.0"]

FROM tools AS test-tools
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN npm install --prefix /opt/playwright --save-exact @playwright/test@1.64.1 \
 && /opt/playwright/node_modules/.bin/playwright install --with-deps chromium

FROM tools AS runtime
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
RUN npm --prefix frontend ci \
 && npm --prefix frontend run build
ENV RAILS_ENV=production
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
