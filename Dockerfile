from ruby:3.0.2-buster

WORKDIR /code

# RUN apt-get update && \
#     apt-get install -y \
#     git

# RUN apt --no-cache add \
#     git \
#     curl-dev \
#     build-base \
#     imagemagick6 imagemagick6-dev imagemagick6-libs

# ENV LD_LIBRARY_PATH /usr/local/lib
# ENV SKIP_INTERACTIVE true

COPY . ./

RUN bundle install

#docker build -t image_vise .
#docker run -e SKIP_INTERACTIVE=true -v $PWD:/code -it image_vise bundle exec rspec
