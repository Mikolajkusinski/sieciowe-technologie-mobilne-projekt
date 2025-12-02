using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;
using SoapWebApi.Interfaces;
using SoapWebApi.Models;

namespace SoapWebApi.Services;

public class MapService : IMapService
{
    private readonly string _mapImagePath;
    private readonly ILogger<MapService> _logger;

    private const double POLAND_MIN_LAT = 49.0;
    private const double POLAND_MAX_LAT = 54.9;
    private const double POLAND_MIN_LON = 14.1;
    private const double POLAND_MAX_LON = 24.2;

    public MapService(ILogger<MapService> logger, IWebHostEnvironment env)
    {
        _logger = logger;
        _mapImagePath = Path.Combine(env.ContentRootPath, "wwwroot", "images", "map.png");

        _logger.LogInformation($"MapService initialized. Map path: {_mapImagePath}");
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
            _logger.LogInformation(
                $"GetMapByPixelCoordinates: TopLeft({request.TopLeft.X}, {request.TopLeft.Y}), BottomRight({request.BottomRight.X}, {request.BottomRight.Y})");

            if (!File.Exists(_mapImagePath))
            {
                _logger.LogWarning($"Map image not found at: {_mapImagePath}");
                return new MapResponse
                {
                    Success = false,
                    Message = $"Map image not found. Path: {_mapImagePath}"
                };
            }

            using var image = Image.Load(_mapImagePath);

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
            _logger.LogError(ex, "Failed to load map image");
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
            _logger.LogInformation(
                $"GetMapByGeoCoordinates: TopLeft(Lat: {request.TopLeft.Latitude}, Lon: {request.TopLeft.Longitude}), BottomRight(Lat: {request.BottomRight.Latitude}, Lon: {request.BottomRight.Longitude})");

            if (!File.Exists(_mapImagePath))
            {
                _logger.LogWarning($"Map image not found at: {_mapImagePath}");
                return new MapResponse
                {
                    Success = false,
                    Message = $"Map image not found. Path: {_mapImagePath}"
                };
            }

            if (!ValidateGeoCoordinates(request))
            {
                return new MapResponse
                {
                    Success = false,
                    Message = "Coordinates exceed Poland bounds"
                };
            }

            using var image = Image.Load(_mapImagePath);

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

            var pixelRequest = new PixelMapRequest
            {
                TopLeft = pixelTopLeft,
                BottomRight = pixelBottomRight
            };

            if (!ValidatePixelCoordinates(pixelRequest, image.Width, image.Height))
            {
                return new MapResponse
                {
                    Success = false,
                    Message = "Invalid pixel coordinates"
                };
            }

            int width = pixelBottomRight.X - pixelTopLeft.X;
            int height = pixelBottomRight.Y - pixelTopLeft.Y;

            image.Mutate(x => x.Crop(new Rectangle(
                pixelTopLeft.X,
                pixelTopLeft.Y,
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
            _logger.LogError(ex, "Failed to load map image from geo coordinates");
            return new MapResponse
            {
                Success = false,
                Message = $"Error: {ex.Message}"
            };
        }
    }

    private PixelCoordinates GeoToPixel(double latitude, double longitude, int imageWidth, int imageHeight)
    {
        double normalizedLon = (longitude - POLAND_MIN_LON) / (POLAND_MAX_LON - POLAND_MIN_LON);
        double normalizedLat = (POLAND_MAX_LAT - latitude) / (POLAND_MAX_LAT - POLAND_MIN_LAT);

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
        bool isValid = request.TopLeft.Latitude >= POLAND_MIN_LAT &&
                       request.TopLeft.Latitude <= POLAND_MAX_LAT &&
                       request.BottomRight.Latitude >= POLAND_MIN_LAT &&
                       request.BottomRight.Latitude <= POLAND_MAX_LAT &&
                       request.TopLeft.Longitude >= POLAND_MIN_LON &&
                       request.TopLeft.Longitude <= POLAND_MAX_LON &&
                       request.BottomRight.Longitude >= POLAND_MIN_LON &&
                       request.BottomRight.Longitude <= POLAND_MAX_LON &&
                       request.TopLeft.Latitude > request.BottomRight.Latitude &&
                       request.TopLeft.Longitude < request.BottomRight.Longitude;

        if (!isValid)
        {
            _logger.LogWarning(
                $"Invalid geo coordinates. Poland bounds: Lat({POLAND_MIN_LAT}-{POLAND_MAX_LAT}), Lon({POLAND_MIN_LON}-{POLAND_MAX_LON}), Request: TopLeft(Lat:{request.TopLeft.Latitude}, Lon:{request.TopLeft.Longitude}), BottomRight(Lat:{request.BottomRight.Latitude}, Lon:{request.BottomRight.Longitude})");
        }

        return isValid;
    }
}