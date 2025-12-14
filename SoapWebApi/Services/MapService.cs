using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;
using SoapWebApi.Interfaces;
using SoapWebApi.Models;

namespace SoapWebApi.Services;

public class MapService : IMapService
{
    private readonly ILogger<MapService> _logger;

    // Anchor bbox for the single base image 1000x1000
    // Top-left geo anchor: (Lat 54.188424, Lon 19.387526)
    // Bottom-right geo anchor: (Lat 54.164336, Lon 19.428238)
    private const double ANCHOR_MIN_LAT = 54.164336; // bottom edge
    private const double ANCHOR_MAX_LAT = 54.188424; // top edge
    private const double ANCHOR_MIN_LON = 19.387526; // left edge
    private const double ANCHOR_MAX_LON = 19.428238; // right edge

    public MapService(ILogger<MapService> logger)
    {
        _logger = logger;
        _logger.LogInformation("MapService initialized");
    }

    public string Ping()
    {
        _logger.LogInformation("Ping method called");
        return $"Map Service is running. Time: {DateTime.Now}";
    }

    public MapResponse GetMapByPixelCoordinates(PixelMapRequest request)
    {
        try
        {
            // Defensive null checks to avoid NRE when deserialization fails
            if (request == null)
            {
                _logger.LogWarning("GetMapByPixelCoordinates: request is null (deserialization failed)");
                return new MapResponse
                {
                    Success = false,
                    Message = "Invalid request: request is null"
                };
            }

            if (request.TopLeft == null || request.BottomRight == null)
            {
                _logger.LogWarning(
                    "GetMapByPixelCoordinates: TopLeft or BottomRight is null. Likely XML namespace mismatch in client request.");
                return new MapResponse
                {
                    Success = false,
                    Message = "Invalid request: TopLeft and BottomRight pixel coordinates are required"
                };
            }

            _logger.LogInformation(
                $"GetMapByPixelCoordinates: TopLeft({request.TopLeft.X}, {request.TopLeft.Y}), BottomRight({request.BottomRight.X}, {request.BottomRight.Y})");

            if (request.ImageData == null || request.ImageData.Length == 0)
            {
                return new MapResponse
                {
                    Success = false,
                    Message = "Image data is required"
                };
            }

            using var image = Image.Load(request.ImageData);

            if (!ValidatePixelCoordinates(request, image.Width, image.Height))
            {
                return new MapResponse
                {
                    Success = false,
                    Message =
                        $"Invalid pixel coordinates. Image size: {image.Width.ToString()}x{image.Height.ToString()}"
                };
            }

            int width = request.BottomRight.X - request.TopLeft.X;
            int height = request.BottomRight.Y - request.TopLeft.Y;

            image.Mutate(x => x.Crop(new Rectangle(
                request.TopLeft.X,
                request.TopLeft.Y,
                width,
                height
            )));

            using var memoryStream = new MemoryStream();
            image.SaveAsJpeg(memoryStream);

            _logger.LogInformation($"Successfully created map crop: {width}x{height}");

            return new MapResponse
            {
                Success = true,
                ImageData = memoryStream.ToArray(),
                ContentType = "image/jpeg",
                Width = width,
                Height = height,
                Message = "Success"
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process map image");
            return new MapResponse
            {
                Success = false,
                Message = $"Error: {ex.Message}"
            };
        }
    }

    public MapResponse GetMapByGeoCoordinates(GeoMapRequest request)
    {
        try
        {
            // Defensive null checks to avoid NRE when deserialization fails or namespaces mismatch
            if (request == null)
            {
                _logger.LogWarning("GetMapByGeoCoordinates: request is null (deserialization failed)");
                return new MapResponse
                {
                    Success = false,
                    Message = "Invalid request: request is null"
                };
            }

            if (request.TopLeft == null || request.BottomRight == null)
            {
                _logger.LogWarning(
                    "GetMapByGeoCoordinates: TopLeft or BottomRight is null. Likely XML namespace mismatch in client request.");
                return new MapResponse
                {
                    Success = false,
                    Message = "Invalid request: TopLeft and BottomRight geo coordinates are required"
                };
            }

            _logger.LogInformation(
                $"GetMapByGeoCoordinates: TopLeft(Lat: {request.TopLeft.Latitude}, Lon: {request.TopLeft.Longitude}), BottomRight(Lat: {request.BottomRight.Latitude}, Lon: {request.BottomRight.Longitude})");

            if (request.ImageData == null || request.ImageData.Length == 0)
            {
                return new MapResponse
                {
                    Success = false,
                    Message = "Image data is required"
                };
            }

            if (!ValidateGeoCoordinates(request))
            {
                return new MapResponse
                {
                    Success = false,
                    Message = "Coordinates exceed allowed bounds"
                };
            }

            using var image = Image.Load(request.ImageData);

            var pixelTopLeft = GeoToPixel(
                request.TopLeft.Latitude,
                request.TopLeft.Longitude,
                image.Width,
                image.Height
            );

            var pixelBottomRight = GeoToPixel(
                request.BottomRight.Latitude,
                request.BottomRight.Longitude,
                image.Width,
                image.Height
            );

            _logger.LogInformation(
                $"Converted to pixels: TopLeft({pixelTopLeft.X}, {pixelTopLeft.Y}), BottomRight({pixelBottomRight.X}, {pixelBottomRight.Y})");

            // Normalize rectangle if needed to be safe
            var left = Math.Min(pixelTopLeft.X, pixelBottomRight.X);
            var right = Math.Max(pixelTopLeft.X, pixelBottomRight.X);
            var top = Math.Min(pixelTopLeft.Y, pixelBottomRight.Y);
            var bottom = Math.Max(pixelTopLeft.Y, pixelBottomRight.Y);

            var pixelRequest = new PixelMapRequest
            {
                TopLeft = new PixelCoordinates { X = left, Y = top },
                BottomRight = new PixelCoordinates { X = right, Y = bottom },
                ImageData = request.ImageData
            };

            if (!ValidatePixelCoordinates(pixelRequest, image.Width, image.Height))
            {
                return new MapResponse
                {
                    Success = false,
                    Message = "Invalid pixel coordinates"
                };
            }

            int width = right - left;
            int height = bottom - top;

            image.Mutate(x => x.Crop(new Rectangle(
                left,
                top,
                width,
                height
            )));

            using var memoryStream = new MemoryStream();
            image.SaveAsJpeg(memoryStream);

            _logger.LogInformation($"Successfully created map crop from geo coordinates: {width}x{height}");

            return new MapResponse
            {
                Success = true,
                ImageData = memoryStream.ToArray(),
                ContentType = "image/jpeg",
                Width = width,
                Height = height,
                Message = "Success"
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process map image from geo coordinates");
            return new MapResponse
            {
                Success = false,
                Message = $"Error: {ex.Message}"
            };
        }
    }

    private PixelCoordinates GeoToPixel(double latitude, double longitude, int imageWidth, int imageHeight)
    {
        // Linear mapping based on anchors
        double normalizedLon = (longitude - ANCHOR_MIN_LON) / (ANCHOR_MAX_LON - ANCHOR_MIN_LON);
        // y-axis inversion for image coordinates (top=0): higher latitude -> smaller y
        double normalizedLat = (ANCHOR_MAX_LAT - latitude) / (ANCHOR_MAX_LAT - ANCHOR_MIN_LAT);

        normalizedLon = Math.Max(0, Math.Min(1, normalizedLon));
        normalizedLat = Math.Max(0, Math.Min(1, normalizedLat));

        return new PixelCoordinates
        {
            X = (int)(normalizedLon * imageWidth),
            Y = (int)(normalizedLat * imageHeight)
        };
    }

    private bool ValidatePixelCoordinates(PixelMapRequest request, int imageWidth, int imageHeight)
    {
        bool isValid = request.TopLeft.X >= 0 &&
                       request.TopLeft.Y >= 0 &&
                       request.BottomRight.X <= imageWidth &&
                       request.BottomRight.Y <= imageHeight &&
                       request.TopLeft.X < request.BottomRight.X &&
                       request.TopLeft.Y < request.BottomRight.Y;

        if (!isValid)
        {
            _logger.LogWarning(
                $"Invalid pixel coordinates. Image: {imageWidth}x{imageHeight}, Request: TopLeft({request.TopLeft.X},{request.TopLeft.Y}), BottomRight({request.BottomRight.X},{request.BottomRight.Y})");
        }

        return isValid;
    }

    private bool ValidateGeoCoordinates(GeoMapRequest request)
    {
        bool isValid = request.TopLeft.Latitude >= ANCHOR_MIN_LAT &&
                       request.TopLeft.Latitude <= ANCHOR_MAX_LAT &&
                       request.BottomRight.Latitude >= ANCHOR_MIN_LAT &&
                       request.BottomRight.Latitude <= ANCHOR_MAX_LAT &&
                       request.TopLeft.Longitude >= ANCHOR_MIN_LON &&
                       request.TopLeft.Longitude <= ANCHOR_MAX_LON &&
                       request.BottomRight.Longitude >= ANCHOR_MIN_LON &&
                       request.BottomRight.Longitude <= ANCHOR_MAX_LON &&
                       request.TopLeft.Latitude > request.BottomRight.Latitude &&
                       request.TopLeft.Longitude < request.BottomRight.Longitude;

        if (!isValid)
        {
            _logger.LogWarning(
                $"Invalid geo coordinates. Allowed bounds: Lat({ANCHOR_MIN_LAT}-{ANCHOR_MAX_LAT}), Lon({ANCHOR_MIN_LON}-{ANCHOR_MAX_LON}), Request: TopLeft(Lat:{request.TopLeft.Latitude}, Lon:{request.TopLeft.Longitude}), BottomRight(Lat:{request.BottomRight.Latitude}, Lon:{request.BottomRight.Longitude})");
        }

        return isValid;
    }
}