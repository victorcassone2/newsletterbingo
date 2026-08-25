require "test_helper"

class WordImageTest < ActionDispatch::IntegrationTest
  PNG_SIGNATURE = "\x89PNG".b

  setup do
    @publication = publications(:omaha)
    @game = create_running_game(@publication)
  end

  test "serves today's word as an uncacheable PNG" do
    get word_image_path(@publication.public_code)
    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal PNG_SIGNATURE, response.body.byteslice(0, 4)
    assert_match(/no-cache/, response.headers["Cache-Control"])
  end

  test "still renders when no game is running" do
    @publication.games.destroy_all
    get word_image_path(@publication.public_code)
    assert_response :success
    assert_equal PNG_SIGNATURE, response.body.byteslice(0, 4)
  end

  test "the default block variant renders the fixed retina canvas" do
    get word_image_path(@publication.public_code)
    width, height = response.body.byteslice(16, 8).unpack("N2")
    assert_equal [ WordImage::WIDTH, WordImage::HEIGHT ], [ width, height ]
  end

  test "the inline variant serves the word trimmed to line height" do
    get word_image_path(@publication.public_code, variant: "inline")
    assert_response :success
    width, height = response.body.byteslice(16, 8).unpack("N2")
    assert_equal WordImage::INLINE_HEIGHT, height
    assert width < WordImage::WIDTH
  end

  test "an unknown public code is a 404" do
    get word_image_path("pub_nope")
    assert_response :not_found
  end

  test "a label that looks like an ImageMagick file read renders as a literal" do
    image = WordImage.new(@publication, label: "@/etc/passwd")
    assert_equal PNG_SIGNATURE, image.png.byteslice(0, 4)
  end
end
